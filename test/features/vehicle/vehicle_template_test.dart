/// vehicle_template_test.dart – Fahrzeug-Vorlagen: Parser, ausgelieferte
/// Dateien und das Anlegen (Issue #55).
library;
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template_service.dart';

import '../../helpers/test_database.dart';

void main() {
  // Für rootBundle: Der Vorlagen-Service legt fehlende Katalog-Geräte aus
  // dem gebündelten standard_catalog.json nach (Issue #86).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseVehicleTemplate', () {
    test('liest Vorlage mit Beladung vollständig', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'lf20',
        'name': 'LF 20',
        'type': 'LF 20',
        'note': 'Hinweis',
        'compartments': [
          {'label': 'G1', 'position': 0},
          {'label': 'G2', 'position': 1},
        ],
        'loading': {
          'source': 'Feuerwehrschule',
          'source_url': 'https://example.invalid/liste.pdf',
          'items': [
            {'equipment_id': 'std_b_druckschlauch_20m', 'quantity': 14},
          ],
        },
      }))!;

      expect(t.id, 'lf20');
      expect(t.type, 'LF 20');
      expect(t.note, 'Hinweis');
      expect(t.compartments.map((c) => c.label), ['G1', 'G2']);
      expect(t.hasLoading, isTrue);
      expect(t.loading!.source, 'Feuerwehrschule');
      expect(t.loading!.items.single.quantity, 14);
    });

    test('Vorlage ohne Beladung meldet hasLoading = false', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'mtw',
        'name': 'MTW',
        'type': 'MTW',
        'compartments': [
          {'label': 'Laderaum', 'position': 0},
        ],
      }))!;
      expect(t.hasLoading, isFalse);
      expect(t.loading, isNull);
    });

    test('leerer loading-Block zählt nicht als Beladung', () {
      // Sonst böte die UI „mit Normbeladung" an und legte nichts an.
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [],
        'loading': {'source': 'irgendwo', 'items': []},
      }))!;
      expect(t.hasLoading, isFalse);
    });

    test('ergänzt fehlende Positionen fortlaufend', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'A'},
          {'label': 'B'},
        ],
      }))!;
      expect(t.compartments.map((c) => c.position), [0, 1]);
    });

    test('überspringt Fächer und Positionen ohne Pflichtangabe', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'A'},
          {'position': 1},
          {'label': ''},
        ],
        'loading': {
          'source': 's',
          'items': [
            {'equipment_id': 'std_a', 'quantity': 2},
            {'quantity': 5},
          ],
        },
      }))!;
      expect(t.compartments.map((c) => c.label), ['A']);
      expect(t.loading!.items.single.equipmentId, 'std_a');
    });

    test('liefert null statt zu werfen', () {
      expect(parseVehicleTemplate('kein json'), isNull);
      expect(parseVehicleTemplate('[]'), isNull);
      // Pflichtangaben fehlen.
      expect(parseVehicleTemplate('{"name":"X"}'), isNull);
    });
  });

  group('die ausgelieferten Vorlagen', () {
    late final Map<String, VehicleTemplate> templates = {
      for (final id in kBundledVehicleTemplateIds)
        id: parseVehicleTemplate(
            File('$kVehicleTemplateDir/$id/template.json').readAsStringSync())!,
    };

    late final Set<String> catalogIds = (() {
      final raw = jsonDecode(File(
              'assets/equipment_library/catalog/standard_catalog.json')
          .readAsStringSync());
      final items = raw is List ? raw : (raw as Map)['items'] as List;
      return items.map((e) => (e as Map)['id'] as String).toSet();
    })();

    test('alle im Code gelisteten Vorlagen existieren und sind lesbar', () {
      expect(templates, hasLength(kBundledVehicleTemplateIds.length));
      for (final entry in templates.entries) {
        expect(entry.value.id, entry.key,
            reason: 'die id im JSON muss dem Verzeichnisnamen entsprechen — '
                'sonst lädt der Provider etwas anderes als erwartet');
      }
    });

    test('jede Vorlage ist in pubspec.yaml als Asset eingetragen', () {
      // Ohne Eintrag fehlt die Datei im Build und die Vorlage verschwindet
      // still — im Test läuft sie über das Dateisystem und fällt nicht auf.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final id in kBundledVehicleTemplateIds) {
        expect(pubspec, contains('$kVehicleTemplateDir/$id/template.json'),
            reason: 'Vorlage $id fehlt in den Assets');
      }
    });

    test('jede Vorlage hat Geräteräume', () {
      for (final t in templates.values) {
        expect(t.compartments, isNotEmpty, reason: '${t.id} ohne Geräteräume');
      }
    });

    test('Geräteraum-Positionen sind eindeutig', () {
      for (final t in templates.values) {
        final positions = t.compartments.map((c) => c.position).toList();
        expect(positions.toSet(), hasLength(positions.length),
            reason: '${t.id} hat doppelte Positionen');
      }
    });

    test('jede Beladungsposition verweist auf ein Gerät im Katalog', () {
      // ⚠️ Der wichtigste Test dieser Datei: Eine unbekannte ID fällt zur
      // Laufzeit nicht auf — das Gerät wird beim Anlegen einfach übersprungen,
      // und die Wehr bekommt eine unvollständige Beladung, ohne es zu merken.
      for (final t in templates.values) {
        for (final item in t.loading?.items ?? const []) {
          expect(catalogIds, contains(item.equipmentId),
              reason: '${t.id}: ${item.equipmentId} steht nicht im Katalog');
        }
      }
    });

    test('Beladungspositionen haben plausible Mengen und keine Dubletten', () {
      for (final t in templates.values) {
        final ids = <String>[];
        for (final item in t.loading?.items ?? const []) {
          expect(item.quantity, greaterThan(0),
              reason: '${t.id}: ${item.equipmentId} mit Menge 0');
          ids.add(item.equipmentId);
        }
        expect(ids.toSet(), hasLength(ids.length),
            reason: '${t.id} nennt ein Gerät mehrfach');
      }
    });

    test('jede Vorlage mit Beladung nennt ihre Quelle', () {
      // Ohne Herkunft könnte jemand die Liste für den geprüften Stand der
      // eigenen Wehr halten.
      for (final t in templates.values.where((t) => t.hasLoading)) {
        expect(t.loading!.source, isNotEmpty);
        expect(t.loading!.source.toLowerCase(), contains('din'),
            reason: '${t.id}: die Quelle sollte die Norm benennen');
      }
    });

    test('HLF 20 trägt mehr als LF 20 — die Zusatzbeladung', () {
      // Fachliche Gegenprobe: Das HLF ist ein LF plus TH-Satz.
      final lf = templates['lf20']!;
      final hlf = templates['hlf20']!;
      expect(hlf.loading!.items.length,
          greaterThan(lf.loading!.items.length));
      final hlfIds = hlf.loading!.items.map((i) => i.equipmentId).toSet();
      for (final item in lf.loading!.items) {
        expect(hlfIds, contains(item.equipmentId),
            reason: 'HLF muss die LF-Beladung enthalten');
      }
      expect(hlfIds, containsAll(['std_spreizer', 'std_schneidgeraet']));
    });

    test('Vorlagen ohne Beladung sagen das im Hinweis', () {
      for (final t in templates.values.where((t) => !t.hasLoading)) {
        expect(t.note.toLowerCase(), contains('keine'),
            reason: '${t.id} sollte erklären, warum keine Beladung dabei ist');
      }
    });
  });

  group('VehicleTemplateService', () {
    late AppDatabase db;
    late VehicleTemplateService service;

    setUp(() {
      db = createTestDatabase();
      service = VehicleTemplateService(db);
    });
    tearDown(() => db.close());

    VehicleTemplate template({List<TemplateItem> items = const []}) =>
        VehicleTemplate(
          id: 'test',
          name: 'Testfahrzeug',
          type: 'LF 20',
          note: '',
          compartments: const [
            TemplateCompartment(label: 'G1', position: 0),
            TemplateCompartment(label: 'G2', position: 1),
          ],
          loading: items.isEmpty
              ? null
              : TemplateLoading(source: 'DIN Test', items: items),
        );

    test('legt Fahrzeug und Geräteräume an', () async {
      final result = await service.apply(
        template(),
        name: 'Florian 1/46',
        withLoading: false,
      );

      expect(result.compartmentCount, 2);
      expect(result.itemCount, 0);

      final vehicle = (await db.vehicleDao.getAll()).single;
      expect(vehicle.name, 'Florian 1/46');
      expect(vehicle.type, 'LF 20', reason: 'der Typ kommt aus der Vorlage');

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      expect(comps.map((c) => c.label), ['G1', 'G2']);
    });

    test('übernimmt Kennzeichen und Bild', () async {
      final result = await service.apply(
        template(),
        name: 'X',
        licensePlate: 'FW-AB 123',
        imagePath: '/pfad/bild.jpg',
        withLoading: false,
      );
      final vehicle =
          (await db.vehicleDao.getAll()).firstWhere((v) => v.id == result.vehicleId);
      expect(vehicle.licensePlate, 'FW-AB 123');
      expect(vehicle.imagePath, '/pfad/bild.jpg');
    });

    test('legt ohne Beladung auch kein Sammelfach an', () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_x', quantity: 1),
        ]),
        name: 'X',
        withLoading: false,
      );
      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      expect(comps.map((c) => c.label),
          isNot(contains(kUnassignedCompartmentLabel)));
    });

    test('legt die Beladung gesammelt ins Sammelfach', () async {
      // Die Raumzuordnung ist nicht genormt — sie zu erfinden wäre genau da
      // falsch, wo die App zum Lernen dient.
      final equipmentId = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(
          name: 'B-Druckschlauch 20 m',
          libraryEquipmentId: const Value('std_b_druckschlauch_20m'),
        ),
      );

      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_b_druckschlauch_20m', quantity: 14),
        ]),
        name: 'X',
        withLoading: true,
      );

      expect(result.itemCount, 1);
      expect(result.missingEquipment, isEmpty);
      expect(result.compartmentCount, 3, reason: 'zwei Räume plus Sammelfach');

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final unassigned =
          comps.firstWhere((c) => c.label == kUnassignedCompartmentLabel);
      expect(unassigned.position, 2, reason: 'ans Ende, nicht zwischen die G-Räume');

      final assignments =
          await db.assignmentDao.getByCompartment(unassigned.id);
      expect(assignments.single.equipmentId, equipmentId);
      expect(assignments.single.quantity, 14);
    });

    test('das Sammelfach trägt die Kennzeichnung im Namen', () async {
      // Bewusst statt einer Datenbankspalte: überall sichtbar, wo das Fach
      // auftaucht, und weg, sobald der Gerätewart verteilt hat.
      expect(kUnassignedCompartmentLabel.toLowerCase(), contains('ungeprüft'));
    });

    test('legt Positionen aus dem gebündelten Katalog nach (Issue #86)',
        () async {
      // Ausgangslage wie im Feld: Das Gerät hat den zentralen Datenbestand
      // gezogen, der Pull hat den lokalen Bestand ersetzt und der Seeder
      // darf nie wieder laufen — der Katalog fehlt KOMPLETT. Vorher entstand
      // hier ein Fahrzeug ganz ohne Geräte, obwohl „mit Normbeladung"
      // gewählt war.
      expect(await db.equipmentDao.getByLibraryId('std_b_druckschlauch_20m'),
          isNull,
          reason: 'Vorbedingung: Katalog ist nicht geseedet');

      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_b_druckschlauch_20m', quantity: 14),
        ]),
        name: 'X',
        withLoading: true,
      );

      expect(result.itemCount, 1);
      expect(result.missingEquipment, isEmpty);

      final nachgelegt =
          await db.equipmentDao.getByLibraryId('std_b_druckschlauch_20m');
      expect(nachgelegt, isNotNull, reason: 'aus dem Katalog nachgelegt');
      expect(nachgelegt!.isCustom, isFalse);

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final unassigned =
          comps.firstWhere((c) => c.label == kUnassignedCompartmentLabel);
      final assignments =
          await db.assignmentDao.getByCompartment(unassigned.id);
      expect(assignments.single.equipmentId, nachgelegt.id);
      expect(assignments.single.quantity, 14);
    });

    test('meldet Geräte, die nicht im Katalog stehen', () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_gibts_nicht', quantity: 1),
        ]),
        name: 'X',
        withLoading: true,
      );
      expect(result.itemCount, 0);
      expect(result.missingEquipment, ['std_gibts_nicht']);
    });
  });
}
