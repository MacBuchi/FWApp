/// bestand_export_test.dart – Der volle Bestand als CSV (Issue #176).
///
/// Geprüft wird die Zeilenregel, und zwar an der Eigenschaft, an der ein
/// aufnehmendes System hängt: **Die Summe der Anzahl je Zuordnung ist die
/// Stückzahl.** Geht das daneben, hat die Wehr nach dem Import plötzlich
/// drei Feuerlöscher statt vier — und niemand sieht, woran es lag.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/export/csv_datei.dart';
import 'package:fwapp/features/inventory/data/bestand_export.dart';

void main() {
  final jetzt = DateTime(2026, 9, 22, 14, 30);

  VehicleData fahrzeug(int id, String name, {String? kennzeichen}) =>
      VehicleData(
        id: id,
        name: name,
        type: 'HLF 20',
        licensePlate: kennzeichen,
        createdAt: jetzt,
        updatedAt: jetzt,
      );

  CompartmentData fach(int id, int fahrzeugId, String label,
          {int position = 0}) =>
      CompartmentData(
        id: id,
        vehicleId: fahrzeugId,
        label: label,
        position: position,
        gridColSpan: 1,
        updatedAt: jetzt,
      );

  AssignmentData zuordnung(int id, int fachId, int geraetId, int anzahl) =>
      AssignmentData(
        id: id,
        compartmentId: fachId,
        equipmentId: geraetId,
        quantity: anzahl,
        updatedAt: jetzt,
      );

  EquipmentItemData geraet(int id, String name, {String? kurz}) =>
      EquipmentItemData(
        id: id,
        name: name,
        shortName: kurz,
        equipmentFunctionsJson: '[]',
        deploymentScenariosJson: '[]',
        description: '',
        isCustom: false,
        typeDirty: false,
        extraAttributesJson: '{}',
        trainingQuestionsJson: '[]',
        typicalUseJson: '[]',
        updatedAt: jetzt,
      );

  EquipmentInstanceData einheit(int id, int geraetId,
          {int? fachId, String? kennung, String notiz = ''}) =>
      EquipmentInstanceData(
        id: id,
        equipmentId: geraetId,
        compartmentId: fachId,
        identifier: kennung,
        notes: notiz,
        isActive: true,
        updatedAt: jetzt,
      );

  EquipmentTagData code(int id, int einheitId, String wert) => EquipmentTagData(
        id: id,
        instanceId: einheitId,
        code: wert,
        kind: EquipmentTags.kindQr,
        selfIssued: true,
        createdAt: jetzt,
        dirty: false,
      );

  InspectionScheduleData pruefung(int id, int einheitId, String titel,
          DateTime faellig) =>
      InspectionScheduleData(
        id: id,
        instanceId: einheitId,
        kind: InspectionSchedules.kindRecurring,
        title: titel,
        dueAt: faellig,
        notes: '',
        updatedAt: jetzt,
      );

  String csv({
    List<VehicleData> fahrzeuge = const [],
    List<CompartmentData> faecher = const [],
    List<AssignmentData> zuordnungen = const [],
    List<EquipmentItemData> geraete = const [],
    List<EquipmentInstanceData> einheiten = const [],
    List<EquipmentTagData> codes = const [],
    List<InspectionScheduleData> pruefungen = const [],
  }) =>
      bestandCsv(
        fahrzeuge: fahrzeuge,
        faecher: faecher,
        zuordnungen: zuordnungen,
        geraete: geraete,
        einheiten: einheiten,
        codes: codes,
        pruefungen: pruefungen,
      );

  /// Die Datenzeilen, ohne BOM und ohne Kopfzeile, je Zelle zerlegt.
  List<List<String>> datenzeilen(String datei) => datei
      .replaceFirst('﻿', '')
      .trim()
      .split('\r\n')
      .skip(1)
      .where((z) => z.isNotEmpty)
      .map((z) => z.split(kCsvTrenner))
      .toList();

  test('die Kopfzeile ist die erste Zeile — kein Vorspann', () {
    // Ein Vorspann macht die Datei für jeden Importer kaputt.
    final datei = csv();
    final erste = datei.replaceFirst('﻿', '').split('\r\n').first;
    expect(erste.split(kCsvTrenner), kBestandCsvKopf);
  });

  test('ein Gerät ohne geführte Einheiten ist eine Sammelzeile', () {
    // Zehn Schlauchbinder führt niemand einzeln.
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20', kennzeichen: 'FW-FW 20')],
      faecher: [fach(1, 1, 'G1')],
      zuordnungen: [zuordnung(1, 1, 7, 10)],
      geraete: [geraet(7, 'Schlauchbinder')],
    );

    final zeilen = datenzeilen(datei);
    expect(zeilen, hasLength(1));
    expect(zeilen.single[0], 'HLF 20');
    expect(zeilen.single[1], 'FW-FW 20');
    expect(zeilen.single[2], 'G1');
    expect(zeilen.single[3], 'Schlauchbinder');
    expect(zeilen.single[5], '10');
    expect(zeilen.single[6], '', reason: 'Keine Einheit, also keine Kennung.');
  });

  test('geführte Einheiten stehen einzeln, mit Anzahl 1', () {
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20')],
      faecher: [fach(1, 1, 'G5')],
      zuordnungen: [zuordnung(1, 1, 7, 2)],
      geraete: [geraet(7, 'Pressluftatmer', kurz: 'PA')],
      einheiten: [
        einheit(1, 7, fachId: 1, kennung: 'Flasche 3'),
        einheit(2, 7, fachId: 1, kennung: 'Flasche 4'),
      ],
    );

    final zeilen = datenzeilen(datei);
    expect(zeilen, hasLength(2));
    expect(zeilen.map((z) => z[6]), ['Flasche 3', 'Flasche 4']);
    expect(zeilen.map((z) => z[5]), ['1', '1']);
    expect(zeilen.first[4], 'PA');
  });

  test('⚠️ die Summe der Anzahl ist die Stückzahl — auch gemischt', () {
    // Vier Feuerlöscher, zwei davon einzeln geführt. Ohne die Restzeile
    // hätte die Wehr nach dem Import zwei statt vier.
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20')],
      faecher: [fach(1, 1, 'G2')],
      zuordnungen: [zuordnung(1, 1, 7, 4)],
      geraete: [geraet(7, 'Feuerlöscher')],
      einheiten: [
        einheit(1, 7, fachId: 1, kennung: 'FL 1'),
        einheit(2, 7, fachId: 1, kennung: 'FL 2'),
      ],
    );

    final zeilen = datenzeilen(datei);
    expect(zeilen, hasLength(3));
    final summe =
        zeilen.map((z) => int.parse(z[5])).reduce((a, b) => a + b);
    expect(summe, 4);
    expect(zeilen.last[6], '', reason: 'Die Restzeile führt keine Einheit.');
    expect(zeilen.last[5], '2');
  });

  test('mehr Einheiten als Stückzahl erzeugt keine negative Restzeile', () {
    // Kommt vor, wenn jemand Einheiten anlegt und die Stückzahl nicht
    // nachzieht. Eine Zeile mit „-1" wäre für jeden Importer Gift.
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20')],
      faecher: [fach(1, 1, 'G2')],
      zuordnungen: [zuordnung(1, 1, 7, 1)],
      geraete: [geraet(7, 'Feuerlöscher')],
      einheiten: [
        einheit(1, 7, fachId: 1, kennung: 'FL 1'),
        einheit(2, 7, fachId: 1, kennung: 'FL 2'),
      ],
    );

    final zeilen = datenzeilen(datei);
    expect(zeilen, hasLength(2));
    expect(zeilen.every((z) => int.parse(z[5]) > 0), isTrue);
  });

  test('eine Einheit im anderen Fach zählt dort und nicht hier', () {
    // Dasselbe Gerät liegt in zwei Fächern — die Einheit ist die genauere
    // Angabe, dieselbe Regel wie beim Abhaken.
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20')],
      faecher: [fach(1, 1, 'G1', position: 0), fach(2, 1, 'G2', position: 1)],
      zuordnungen: [zuordnung(1, 1, 7, 1), zuordnung(2, 2, 7, 1)],
      geraete: [geraet(7, 'Strahlrohr C')],
      einheiten: [einheit(1, 7, fachId: 2, kennung: 'SR 2')],
    );

    final zeilen = datenzeilen(datei);
    expect(zeilen, hasLength(2));
    // G1 hat keine Einheit → Sammelzeile; G2 hat die Einheit.
    expect(zeilen[0][2], 'G1');
    expect(zeilen[0][6], '');
    expect(zeilen[1][2], 'G2');
    expect(zeilen[1][6], 'SR 2');
  });

  test('Fächer stehen in Einbaureihenfolge, nicht nach ID', () {
    final datei = csv(
      fahrzeuge: [fahrzeug(1, 'HLF 20')],
      faecher: [fach(9, 1, 'G1', position: 0), fach(2, 1, 'Dach', position: 1)],
      zuordnungen: [zuordnung(1, 9, 7, 1), zuordnung(2, 2, 7, 1)],
      geraete: [geraet(7, 'Steckleiter')],
    );

    expect(datenzeilen(datei).map((z) => z[2]), ['G1', 'Dach']);
  });

  group('was an keinem Fahrzeug hängt', () {
    test('steht am Ende unter Lager, statt zu fehlen', () {
      // Ein Verzeichnis, das die Reserve wegließe, wäre beim Archivieren
      // schlicht falsch.
      final datei = csv(
        fahrzeuge: [fahrzeug(1, 'HLF 20')],
        faecher: [fach(1, 1, 'G1')],
        zuordnungen: [zuordnung(1, 1, 7, 1)],
        geraete: [geraet(7, 'Pressluftatmer')],
        einheiten: [einheit(5, 7, kennung: 'Reserve 1')],
      );

      final zeilen = datenzeilen(datei);
      expect(zeilen, hasLength(2));
      expect(zeilen.last[0], kOhneFahrzeug);
      expect(zeilen.last[2], '');
      expect(zeilen.last[6], 'Reserve 1');
      expect(zeilen.last[3], 'Pressluftatmer',
          reason: 'Ohne Fahrzeug, aber nicht ohne Gerätenamen.');
    });

    test('auch ganz ohne Fuhrpark kommt der Bestand heraus', () {
      final datei = csv(
        geraete: [geraet(7, 'Pressluftatmer')],
        einheiten: [einheit(5, 7, kennung: 'Reserve 1')],
      );
      expect(datenzeilen(datei), hasLength(1));
    });
  });

  group('was an der Einheit hängt', () {
    test('mehrere Codes stehen durch Leerzeichen getrennt', () {
      // Eindeutig, weil `normalisiereTagCode` JEDEN Leerraum aus einem Code
      // wirft — auch den mittendrin.
      final datei = csv(
        fahrzeuge: [fahrzeug(1, 'HLF 20')],
        faecher: [fach(1, 1, 'G5')],
        zuordnungen: [zuordnung(1, 1, 7, 1)],
        geraete: [geraet(7, 'Pressluftatmer')],
        einheiten: [einheit(1, 7, fachId: 1, kennung: 'Flasche 3')],
        codes: [code(1, 1, 'FW-7K2M9Q'), code(2, 1, '4006381333931')],
      );

      expect(datenzeilen(datei).single[7], 'FW-7K2M9Q 4006381333931');
    });

    test('Prüfungen kommen mit Titel und Datum, mehrere nacheinander', () {
      final datei = csv(
        fahrzeuge: [fahrzeug(1, 'HLF 20')],
        faecher: [fach(1, 1, 'G5')],
        zuordnungen: [zuordnung(1, 1, 7, 1)],
        geraete: [geraet(7, 'Pressluftatmer')],
        einheiten: [einheit(1, 7, fachId: 1, kennung: 'Flasche 3')],
        pruefungen: [
          pruefung(1, 1, 'Sichtprüfung', DateTime(2027, 3, 1)),
          pruefung(2, 1, 'Druckprüfung', DateTime(2029, 12, 24)),
        ],
      );

      expect(datenzeilen(datei).single[8],
          'Sichtprüfung: 01.03.2027 | Druckprüfung: 24.12.2029');
    });

    test('eine Notiz mit Semikolon zerlegt die Zeile nicht', () {
      // Der Grund, warum hier ein Paket kodiert und nicht ein `join`.
      final datei = csv(
        fahrzeuge: [fahrzeug(1, 'HLF 20')],
        faecher: [fach(1, 1, 'G5')],
        zuordnungen: [zuordnung(1, 1, 7, 1)],
        geraete: [geraet(7, 'Pressluftatmer')],
        einheiten: [
          einheit(1, 7, fachId: 1, kennung: 'F 3', notiz: 'Ventil; tauschen')
        ],
      );

      expect(datei, contains('"Ventil; tauschen"'));
      expect(datenzeilen(datei).single.length,
          greaterThan(kBestandCsvKopf.length - 1));
    });
  });

  test('der Dateiname sortiert chronologisch und trägt die Wehr', () {
    expect(
      bestandDateiname(wehr: 'Feuerwehr Grünbach', zeitpunkt: jetzt),
      'bestand-feuerwehr-gruenbach-2026-09-22.csv',
    );
    expect(bestandDateiname(zeitpunkt: jetzt), 'bestand-wehr-2026-09-22.csv');
  });
}
