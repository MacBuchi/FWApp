/// standard_catalog_test.dart – Namens-Zuordnung des Standard-Katalogs.
///
/// Grundlage für das automatische Symbolbild beim Anlegen (Issue #86:
/// ein Fahrzeug wird Raum für Raum abgebildet, jedes Normgerät soll ohne
/// Umweg über die Bildbibliothek sein Piktogramm bekommen).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/standard_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StandardCatalog katalog;
  setUpAll(() async => katalog = await StandardCatalog.load());

  group('eintrag() – der Inhalt hinter einer Katalog-ID (Issue #102)', () {
    test('liefert auch, was das Formular gar nicht anzeigt', () {
      final e = katalog.eintrag('std_leitkegel')!;
      expect(e.name, 'Verkehrsleitkegel 500 mm');
      expect(e.kurzname, 'Leitkegel');
      expect(e.beschreibung, contains('Reflexstreifen'));
      expect(e.funktionen, ['ABSPERREN']);
      // Genau diese beiden Listen haben im Formular kein Eingabefeld —
      // ohne sie käme ein aus dem Katalog angelegtes Gerät leer an.
      expect(e.typischeVerwendung, hasLength(2));
      expect(e.trainingsfragen, hasLength(2));
    });

    test('unbekannte ID liefert null statt zu werfen', () {
      // Kommt vor, wenn der zentrale Bestand neuer ist als der mitgelieferte
      // Katalog dieser App-Version.
      expect(katalog.eintrag('std_gibt_es_nicht'), isNull);
    });
  });

  test('findet Katalog-Geräte über den exakten Namen', () {
    expect(katalog.idFuerName('Verkehrsleitkegel 500 mm'), 'std_leitkegel');
  });

  test('Normalisierung: Groß/Klein, Rand-Leerraum, Umlaute', () {
    expect(katalog.idFuerName('  VERKEHRSLEITKEGEL 500 MM '), 'std_leitkegel');
    // „Lübecker Hütchen" steht mit ü im Katalog — getippt wird beides.
    expect(katalog.idFuerName('luebecker huetchen'), 'std_leitkegel');
  });

  test('findet über Kurznamen und Aliasse', () {
    expect(katalog.idFuerName('Leitkegel'), 'std_leitkegel');
    expect(katalog.idFuerName('B-Schlauch'), 'std_b_druckschlauch_20m');
    expect(katalog.idFuerName('Rettungsspreizer'), 'std_spreizer');
  });

  test('kein Treffer heißt null — nie ein geratenes Bild', () {
    // Bewusst KEIN Fuzzy-Matching: Das Ergebnis wählt unbeaufsichtigt ein
    // Symbolbild, und ein falsches Bild wiegt schwerer als gar keins.
    expect(katalog.idFuerName('Kaffeemaschine'), isNull);
    expect(katalog.idFuerName(''), isNull);
  });

  test('der leere Katalog antwortet leer statt zu werfen', () {
    expect(StandardCatalog.empty().idFuerName('Leitkegel'), isNull);
  });
}
