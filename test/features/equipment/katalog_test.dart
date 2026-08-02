/// katalog_test.dart – Der Weg in den und aus dem Gerätekatalog
/// (Issues #102 und #103).
///
/// Zwei Bedienstellen, die zusammengehören: Ein Gerät lässt sich AUS dem
/// mitgelieferten Katalog anlegen, und ein selbst angelegtes lässt sich FÜR
/// den Katalog vorschlagen. Beide waren vorher nicht da — das Formular kannte
/// den Katalog nur passiv (Piktogramm bei exaktem Namenstreffer), und einen
/// Vorschlagsweg gab es gar nicht.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/equipment/presentation/providers/image_library_providers.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_detail_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_form_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/image_library_screen.dart';
import 'package:fwapp/features/feedback/data/feedback_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  // ⚠️ Katalog und Bildbibliothek lesen per `rootBundle`, und das liefert in
  // der simulierten Zeit eines Widget-Tests NIE (AGENTS.md § Stolperfallen)
  // — `pumpAndSettle` läuft dann am Fortschrittsring der Bibliothek in einen
  // Timeout statt in einen Fehlschlag. Deshalb hier einmal außerhalb laden
  // und über die Provider hineinreichen; genau dafür sind sie Provider.
  late StandardCatalog katalog;
  late List<ImageLibraryEntry> bibliothek;

  setUpAll(() async {
    katalog = await StandardCatalog.load();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    bibliothek = await container.read(imageLibraryProvider.future);
  });

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget app(Widget home) => buildTestApp(
        db: db,
        home: home,
        overrides: [
          standardCatalogProvider.overrideWith((ref) async => katalog),
          imageLibraryProvider.overrideWith((ref) async => bibliothek),
        ],
      );

  // ── #102: aus dem Katalog anlegen ───────────────────────────────────────

  testWidgets('ein Gerät aus dem Katalog bringt seine Herkunft mit',
      (tester) async {
    await tester.pumpWidget(app(const EquipmentFormScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aus dem Gerätekatalog wählen'));
    await tester.pumpAndSettle();

    // Der Wähler ist die Bildbibliothek — dieselbe Suche über Name,
    // Kurzname und Aliasse, die es dafür schon gibt.
    await tester.enterText(
        find.descendant(
            of: find.byType(ImageLibraryScreen),
            matching: find.byType(TextField)),
        'Pylone');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leitkegel').first);
    await tester.pumpAndSettle();

    // Sichtbar übernommen …
    expect(find.widgetWithText(TextField, 'Verkehrsleitkegel 500 mm'),
        findsOneWidget);
    expect(find.textContaining('Katalog-Gerät'), findsOneWidget);

    await tester.dragUntilVisible(
        find.text('Speichern'), find.byType(ListView), const Offset(0, -120));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final zeile = (await db.equipmentDao.getAll()).single;
    expect(zeile.name, 'Verkehrsleitkegel 500 mm');
    expect(zeile.shortName, 'Leitkegel');
    // … und unsichtbar mitgekommen: Genau daran hängt, ob der Server den Typ
    // der Gesamtwehr zusammenführen kann und ob das Lernen Fragen hat.
    expect(zeile.libraryEquipmentId, 'std_leitkegel');
    expect(zeile.isCustom, isFalse);
    expect(zeile.typicalUseJson, contains('Absicherung'));
    expect(zeile.trainingQuestionsJson, contains('Abständen'));
    expect(zeile.imagePath, contains('std_leitkegel'));
    await endTestApp(tester);
  });

  testWidgets('ohne Katalog-Wahl bleibt das Gerät ein eigenes',
      (tester) async {
    await tester.pumpWidget(
        buildTestApp(db: db, home: const EquipmentFormScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Name*'), 'Selbstgebautes');
    await tester.dragUntilVisible(
        find.text('Speichern'), find.byType(ListView), const Offset(0, -120));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final zeile = (await db.equipmentDao.getAll()).single;
    expect(zeile.libraryEquipmentId, isNull);
    expect(zeile.isCustom, isTrue);
    await endTestApp(tester);
  });

  // ── #103: für den Katalog vorschlagen ───────────────────────────────────

  group('katalogVorschlagText', () {
    test('die erste Zeile ist der Gerätename und nichts sonst', () {
      // Daran hängt die Überschrift des Issues, die der Bot daraus baut.
      final text = katalogVorschlagText(
        name: 'Kübelspritze',
        kurzname: 'KS',
        beschreibung: 'Löschgerät für Entstehungsbrände',
        abteilung: '01 – Stadt',
      );
      expect(text.split('\n').first, 'Kübelspritze');
      expect(text, contains('Kurzform: KS'));
      expect(text, contains('01 – Stadt'));
    });

    test('leere Angaben stehen nicht als leere Zeilen drin', () {
      final text = katalogVorschlagText(name: 'Halligan', abteilung: 'Nord');
      expect(text.split('\n'), hasLength(2));
      expect(text, isNot(contains('Kurzform')));
      expect(text, isNot(contains('Beschreibung')));
    });
  });

  group('die Vorschlag-Aktion', () {
    final sitzung = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: const User(
        id: '00000000-0000-0000-0000-000000000001',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'tester@fw.local',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

    Future<void> oeffneMenue(WidgetTester tester, int id,
        {bool angemeldet = true}) async {
      await tester.pumpWidget(buildTestApp(
        db: db,
        home: EquipmentDetailScreen(equipmentId: id),
        overrides: [
          standardCatalogProvider.overrideWith((ref) async => katalog),
          imageLibraryProvider.overrideWith((ref) async => bibliothek),
          if (angemeldet)
            sessionStreamProvider.overrideWith((ref) => Stream.value(sitzung)),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
    }

    testWidgets('steht bei einem selbst angelegten Gerät im Menü',
        (tester) async {
      final id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Eigenbau'));
      await oeffneMenue(tester, id);
      expect(find.text('Für den Katalog vorschlagen'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('fehlt bei einem Katalog-Gerät', (tester) async {
      // Was schon im Katalog steht, kann man nicht dafür vorschlagen.
      final id = await db.equipmentDao.insertEquipment(
          EquipmentItemsCompanion.insert(
              name: 'Verkehrsleitkegel 500 mm',
              libraryEquipmentId: const Value('std_leitkegel')));
      await oeffneMenue(tester, id);
      expect(find.text('Für den Katalog vorschlagen'), findsNothing);
      expect(find.text('Gerät entfernen'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('fehlt ohne Anmeldung', (tester) async {
      // Der Vorschlag läuft über die Feedback-Tabelle — die verlangt ein
      // Konto. Ein toter Menüpunkt wäre schlimmer als keiner.
      final id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Eigenbau'));
      await oeffneMenue(tester, id, angemeldet: false);
      expect(find.text('Für den Katalog vorschlagen'), findsNothing);
      await endTestApp(tester);
    });
  });
}
