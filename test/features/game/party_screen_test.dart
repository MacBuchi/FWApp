/// party_screen_test.dart – Der Party-Modus, wie er am Tisch bedient wird
/// (Issue #160).
///
/// Drei Zusagen hängen allein an der Oberfläche und wären ohne diesen Test
/// nicht abgesichert: Der Übergabe-Schirm darf die Frage **nicht** schon
/// zeigen, das Trinkspiel ist **ab Werk aus**, und eine Fach-Frage nennt
/// **sichtbar ihr Fahrzeug** (Issue #172) — im Modell zu stehen nützt am
/// Tisch niemandem.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/game/party/presentation/screens/party_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Antworttexte bewusst ohne „Richtig"/„Daneben": Das sind die Wörter der
/// Auflösung, und ein Test, der beides verwechselt, prüft nichts.
final testInhalte = PartyInhalte(
  fragen: List.generate(
      12,
      (i) => UnerwarteteFrage(
            frage: 'Testfrage $i',
            antworten: const ['Stimmt', 'Daneben A', 'Daneben B'],
            richtig: 0,
            kategorie: kKategorieWissen,
          )),
  aufgaben: const ['Zehn Liegestütze'],
);

void main() {
  late AppDatabase db;

  /// Der unerwartete Topf kommt seit Issue #174 aus der Wissensdatenbank.
  /// Antworttexte bewusst ohne „Richtig"/„Daneben" — das sind die Wörter der
  /// Auflösung, und ein Test, der beides verwechselt, prüft nichts.
  ///
  /// Mit Fundstelle und Landesangabe, weil der ausgelieferte Bestand sie
  /// hat: Ohne sie liefe der Test an genau dem Fall vorbei, den er sichern
  /// soll.
  Future<void> seedWissen() async {
    for (var i = 0; i < 12; i++) {
      await db.wissenDao.insertFrage(WissensfragenCompanion.insert(
        gebiet: 'recht_organisation',
        frage: 'Testfrage $i',
        antwortenJson: const Value('["Stimmt","Daneben A","Daneben B"]'),
        richtigeJson: const Value('[0]'),
        // Alle mit Bild, damit der Test nicht von der Mischung abhängt —
        // bei einem Gefahrzettel IST das Bild die Frage.
        bildPfad: const Value(
            'assets/knowledge/bilder/gefahrzettel_klasse_3.png'),
        quelleWerk: const Value('FwG BW'),
        quelleFundstelle: const Value('§ 8 Abs. 2'),
        quelleStand: const Value('2025-02-25'),
        geltung: const Value('land'),
        land: const Value('BW'),
        stand: const Value('freigegeben'),
      ));
    }
  }

  setUp(() async {
    db = createTestDatabase();
    await seedWissen();
  });
  tearDown(() => db.close());

  /// Ein Fahrzeug mit vier Fächern und vier verorteten Geräten — genug für
  /// mehrere Fach-Fragen.
  Future<void> seedBestand({String fahrzeug = 'HLF 20'}) async {
    final vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: fahrzeug, type: 'HLF 20'));
    final faecher = <int>[];
    for (final (label, seite) in const [
      ('G1', 'fahrerseite'),
      ('G2', 'beifahrerseite'),
      ('G3', 'fahrerseite'),
      ('G4', 'beifahrerseite'),
    ]) {
      faecher.add(await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
            vehicleId: vehicleId, label: label, seite: Value(seite)),
      ));
    }
    const geraete = ['Spreizer', 'Schere', 'Rettungszylinder', 'Pumpe'];
    for (final (i, name) in geraete.indexed) {
      final geraet = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: name));
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: faecher[i], equipmentId: geraet));
    }
  }

  Future<void> pumpe(WidgetTester tester,
      {PartyInhalte? inhalte, Size groesse = const Size(1200, 2400)}) async {
    tester.view.physicalSize = groesse;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const PartyScreen(),
      overrides: [
        partyInhalteProvider
            .overrideWith((ref) async => inhalte ?? testInhalte),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> spielerEintragen(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
  }

  Future<void> starten(WidgetTester tester,
      {bool trinkspiel = false}) async {
    await spielerEintragen(tester, 'Anna');
    await spielerEintragen(tester, 'Ben');
    if (trinkspiel) {
      await tester.tap(find.text('Trinkspiel'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Losgeht\'s'));
    await tester.pumpAndSettle();
  }

  testWidgets('ein einzelner Spieler kann nicht starten', (tester) async {
    await pumpe(tester);
    await spielerEintragen(tester, 'Anna');

    expect(find.text('Mindestens zwei Spieler.'), findsOneWidget);
    final knopf = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Losgeht\'s'), matching: find.byType(FilledButton)));
    expect(knopf.onPressed, isNull);

    await endTestApp(tester);
  });

  testWidgets('derselbe Name kommt nicht zweimal in die Runde',
      (tester) async {
    await pumpe(tester);
    await spielerEintragen(tester, 'Anna');
    await spielerEintragen(tester, 'anna');

    expect(find.widgetWithText(Chip, 'Anna'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'anna'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('das Trinkspiel ist ab Werk aus', (tester) async {
    await pumpe(tester);

    final schalter = tester.widget<SwitchListTile>(find.ancestor(
        of: find.text('Trinkspiel'), matching: find.byType(SwitchListTile)));
    expect(schalter.value, isFalse);
    // Der Hinweis erscheint erst, wenn jemand den Schalter umlegt.
    expect(find.textContaining('Bereitschaft'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('eingeschaltet sagt das Trinkspiel etwas zur Bereitschaft',
      (tester) async {
    await pumpe(tester);
    await tester.tap(find.text('Trinkspiel'));
    await tester.pumpAndSettle();

    expect(find.text('Wer heute Bereitschaft hat, nimmt die Aufgabe.'),
        findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('die Übergabe nennt den Spieler und verrät die Frage nicht',
      (tester) async {
    await pumpe(tester);
    await starten(tester);

    expect(find.text('Handy weitergeben an'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    // Der springende Punkt: Solange übergeben wird, ist keine Antwort zu
    // sehen. Sonst liest der Vorgänger mit.
    expect(find.text('Stimmt'), findsNothing);

    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();
    expect(find.text('Stimmt'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('falsche Antwort ohne Trinkspiel bleibt folgenlos',
      (tester) async {
    await pumpe(tester);
    await starten(tester);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daneben A'));
    await tester.pumpAndSettle();

    expect(find.text('Daneben'), findsOneWidget);
    expect(find.textContaining('Ein Schluck'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('eine Bildfrage zeigt ihr Bild am Tisch', (tester) async {
    // Der Weg Asset → Datenbank → PartyFrage → Schirm ist lang, und schon
    // einmal fiel auf ihm etwas heraus (die Quelle, Issue #174). Ohne den
    // Gefahrzettel steht am Tisch „Welche Gefahr zeigt dieser Gefahrzettel
    // an?" ohne den Gefahrzettel.
    await pumpe(tester);
    await starten(tester);

    // Auf dem Übergabe-Schirm noch nicht — dort ist die Frage verdeckt.
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    final bilder = find.byType(Image).evaluate().map((e) =>
        (e.widget as Image).image);
    expect(
      bilder.whereType<AssetImage>().map((a) => a.assetName),
      contains('assets/knowledge/bilder/gefahrzettel_klasse_3.png'),
    );

    await endTestApp(tester);
  });

  testWidgets('die Auflösung nennt die Fundstelle und wo sie gilt',
      (tester) async {
    // Der Streit am Tisch endet an der Vorschrift oder an der lautesten
    // Stimme (Issue #174). Vor dem Schritt stand die Quelle nur in der
    // Wissensdatenbank — also dort, wo gerade niemand hinsieht.
    await pumpe(tester);
    await starten(tester);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    // Vor der Antwort nicht: Die Fundstelle wäre ein Hinweis auf die
    // Lösung.
    expect(find.textContaining('FwG BW'), findsNothing);

    await tester.tap(find.text('Stimmt'));
    await tester.pumpAndSettle();

    expect(
        find.text('FwG BW · § 8 Abs. 2 (2025-02-25) · gilt in '
            'Baden-Württemberg'),
        findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('mit Trinkspiel steht die Aufgabe als Alternative daneben',
      (tester) async {
    await pumpe(tester);
    await starten(tester, trinkspiel: true);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daneben B'));
    await tester.pumpAndSettle();

    // „Ein Schluck — ODER" ist die ganze Entscheidung dieses Modus.
    expect(find.text('Ein Schluck — oder:'), findsOneWidget);
    expect(find.text('Zehn Liegestütze'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('Gleichstand heißt Unentschieden, nicht „Sieger: Anna"',
      (tester) async {
    await pumpe(tester);
    await starten(tester);

    // Alle antworten richtig — dann steht es 3:3.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Bereit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stimmt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i < 5 ? 'Weitergeben' : 'Ergebnis'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Unentschieden: Anna und Ben'), findsOneWidget);
    expect(find.textContaining('Sieger'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('am Ende steht die Rangliste', (tester) async {
    await pumpe(tester);
    await starten(tester);

    // Anna trifft immer, Ben nie — das Ergebnis ist damit vorhersagbar.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Bereit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i.isEven ? 'Stimmt' : 'Daneben A'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(i < 5 ? 'Weitergeben' : 'Ergebnis'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Sieger: Anna'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Anna'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await endTestApp(tester);
  });

  testWidgets('die Fach-Frage zeigt das Fahrzeug, bevor geantwortet wird',
      (tester) async {
    // Keine Wissensfragen: Dann bleiben nur Fach-Fragen übrig, und der Test
    // hängt nicht am Zufall der Rundenverteilung. Seit Issue #174 kommt der
    // unerwartete Topf aus der Datenbank — den Asset-Provider zu leeren
    // genügt dafür nicht mehr.
    for (final f in await db.wissenDao.getAll()) {
      await db.wissenDao.deleteFrage(f.id);
    }
    await seedBestand();
    await pumpe(tester, inhalte: PartyInhalte.leer);
    await starten(tester);

    // Auf dem Übergabe-Schirm steht die Kategorie der Runde …
    expect(find.textContaining('Wo liegt was?'), findsOneWidget);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    // … und an der Frage das Fahrzeug, zu dem die vier Fächer gehören.
    expect(find.widgetWithText(Chip, 'HLF 20'), findsOneWidget);
    expect(find.text('In welchem Fach liegt das?'), findsOneWidget);
    // Vor der Antwort, nicht erst in der Auflösung — das war der Fehler.
    expect(find.textContaining('liegt im Fach'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('unerwartete Fragen tragen kein Fahrzeug', (tester) async {
    // Ein Klischee gehört zu keinem Wagen; ein Fahrzeug daneben wäre eine
    // falsche Angabe und keine Hilfe.
    await pumpe(tester);
    await starten(tester);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('der Übergabe-Schirm sagt Runde und Kategorie an',
      (tester) async {
    await pumpe(tester);
    await starten(tester);

    expect(find.text('Runde 1 · Unerwartetes'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('ein langer Fahrzeugname sprengt das Handy nicht',
      (tester) async {
    // Die echten Namen sind lang („HLF 20/16 Florian Musterstadt 1/44"), und
    // der Weg führt über zwei Engstellen: die Fahrzeug-Auswahl im Aufbau und
    // die Kachel an der Frage. Beim ersten Lauf lief die Auswahl um 285
    // Pixel über — statt des Namens stand dort die gestreifte Fehlerfläche.
    // Der Test fällt bei jedem „RenderFlex overflowed" auf diesem Weg.
    // Ohne Wissensfragen bleibt nur die Fach-Frage — nur die trägt die
    // Fahrzeug-Kachel, um die es hier geht (seit Issue #174 kommt der
    // unerwartete Topf aus der Datenbank).
    for (final f in await db.wissenDao.getAll()) {
      await db.wissenDao.deleteFrage(f.id);
    }
    await seedBestand(fahrzeug: 'HLF 20/16 Florian Musterstadt 1/44');
    await pumpe(tester,
        inhalte: PartyInhalte.leer, groesse: const Size(360, 800));
    await starten(tester);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(Chip, 'HLF 20/16 Florian Musterstadt 1/44'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await endTestApp(tester);
  });
}
