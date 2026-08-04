/// profil_screen_test.dart – „Mein Profil": Vorlagen, Baukasten, Speichern
/// (Issue #100).
///
/// Geprüft wird, was der Screen dem Server ÜBERGIBT und was er ANZEIGT — die
/// Rechte stehen nicht zur Debatte, weil `mein_profil_setzen` kein Ziel-Konto
/// kennt und immer auf `auth.uid()` schreibt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/home/presentation/providers/dashboard_providers.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/domain/leistungsabzeichen.dart';
import 'package:fwapp/features/profil/presentation/providers/profil_providers.dart';
import 'package:fwapp/features/profil/presentation/screens/profil_screen.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Merkt sich, was gespeichert werden sollte. `implements` statt `extends`,
/// weil der echte Service einen Supabase-Client im Konstruktor verlangt.
class _MerkService implements ProfilService {
  String? name;
  AvatarKonfiguration? avatar;
  int aufrufe = 0;

  @override
  Future<void> speichere({
    required String anzeigename,
    required AvatarKonfiguration avatar,
  }) async {
    aufrufe++;
    name = anzeigename;
    this.avatar = avatar;
  }
}

/// Der grosse Kopf oben — die Vorschau.
AvatarKonfiguration _vorschau(WidgetTester tester) => tester
    .widgetList<FwAvatar>(find.byType(FwAvatar))
    .firstWhere((a) => a.groesse > 100)
    .konfiguration;

void main() {
  late AppDatabase db;
  late _MerkService service;

  setUp(() {
    db = createTestDatabase();
    service = _MerkService();
  });
  tearDown(() => db.close());

  /// Grosse Prüffläche statt Scrollerei: Der Screen ist lang (36 Vorlagen und
  /// acht Baukasten-Reihen), und `scrollUntilVisible` findet hier mehr als
  /// einen Scrollable — das Textfeld bringt einen eigenen mit.
  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// [level] setzt das Lern-Level fest (Issue #135). Ohne Angabe `null` =
  /// „noch nicht geladen" — dann verhält sich der Screen wie vor dem
  /// Abzeichen, und die übrigen Prüfungen hier bleiben von der Lern-Datenbank
  /// unabhängig.
  Widget host({MeinProfil? profil, int? level}) => buildTestApp(
        db: db,
        home: const ProfilScreen(),
        overrides: [
          supabaseClientProvider.overrideWithValue(null),
          sessionStreamProvider.overrideWith((ref) => Stream.value(null)),
          meinProfilProvider.overrideWith((ref) async =>
              profil ??
              const MeinProfil(username: 'wart.stadt', serverKenntProfil: true)),
          profilServiceProvider.overrideWithValue(service),
          lernLevelProvider.overrideWithValue(level),
        ],
      );

  testWidgets('ohne gespeicherten Kopf steht der Standardkopf da',
      (tester) async {
    await zeige(tester, host());
    expect(_vorschau(tester), const AvatarKonfiguration());
    expect(find.text('wart.stadt'), findsOneWidget);
  });

  testWidgets('ein gespeicherter Kopf und Name werden übernommen',
      (tester) async {
    const kopf = AvatarKonfiguration(gear: 'scba', eyes: 'shades');
    await zeige(tester, host(
      profil: MeinProfil(
        anzeigename: 'Marcus B.',
        username: 'marcus.bucher',
        avatarText: kopf.kodiert,
        serverKenntProfil: true,
      ),
    ));
    expect(_vorschau(tester), kopf);
    // Zweimal: als Überschrift über dem Kopf und im Eingabefeld.
    expect(find.text('Marcus B.'), findsNWidgets(2));
  });

  testWidgets('das erlernte Abzeichen hängt am eigenen Kopf — und nur dort',
      (tester) async {
    // Issue #135. Die 36 Vorlagen darunter sind ein Katalog, kein Mensch, der
    // etwas geleistet hätte — ein Abzeichen an ihnen wäre schlicht falsch.
    await zeige(tester, host(level: 8));

    final koepfe = tester.widgetList<FwAvatar>(find.byType(FwAvatar));
    final eigener = koepfe.firstWhere((a) => a.groesse > 100);
    expect(eigener.abzeichen, Leistungsabzeichen.silber);
    expect(
      koepfe.where((a) => a.groesse <= 100).map((a) => a.abzeichen).toSet(),
      {null},
    );

    // Und darunter steht im Klartext, was die Marke bedeutet.
    expect(find.text('Leistungsabzeichen in Silber'), findsOneWidget);
    expect(find.text('Noch 7 Level bis Gold.'), findsOneWidget);
  });

  testWidgets('ohne geladene Lernzahlen bleibt der Kopf ohne Marke',
      (tester) async {
    await zeige(tester, host());
    expect(
      tester
          .widgetList<FwAvatar>(find.byType(FwAvatar))
          .map((a) => a.abzeichen)
          .toSet(),
      {null},
    );
    expect(find.textContaining('Leistungsabzeichen'), findsNothing);
  });

  testWidgets('eine Vorlage antippen übernimmt den Kopf — aber NICHT den Namen',
      (tester) async {
    await zeige(tester, host(
      profil: const MeinProfil(
        anzeigename: 'Marcus B.',
        username: 'marcus.bucher',
        serverKenntProfil: true,
      ),
    ));

    final vorlage = kAvatarVorlagen.firstWhere((v) => v.rolle == 'Dalmatiner');
    await tester.tap(find.text(vorlage.name));
    await tester.pumpAndSettle();

    expect(_vorschau(tester), vorlage.kopf);
    // Der Vorlagenname gehört dem Avatar, nicht der Person.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Marcus B.',
    );
  });

  testWidgets('der Baukasten ändert genau einen Wert', (tester) async {
    await zeige(tester, host());

    await tester.tap(find.text('Atemschutzmaske'));
    await tester.pumpAndSettle();

    final kopf = _vorschau(tester);
    expect(kopf.gear, 'scba');
    expect(kopf.eyes, const AvatarKonfiguration().eyes);
    expect(kopf.mouth, const AvatarKonfiguration().mouth);
  });

  testWidgets('Speichern übergibt Name und Kopf', (tester) async {
    await zeige(tester, host());

    await tester.enterText(find.byType(TextField), 'Marcus B.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Käppi'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(service.aufrufe, 1);
    expect(service.name, 'Marcus B.');
    expect(service.avatar?.gear, 'cap');
  });

  testWidgets('auf einem Alt-Server ist Speichern gar nicht erst anwählbar',
      (tester) async {
    // Ehrlicher als ein Knopf, der in „Funktion unbekannt" läuft — und der
    // Satz daneben sagt, woran es liegt.
    await zeige(tester, host(
      profil: const MeinProfil(username: 'wart.stadt'),
    ));

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('kennt Profile noch nicht'), findsOneWidget);
  });

  testWidgets('Würfeln ändert den Kopf', (tester) async {
    await zeige(tester, host());

    final vorher = _vorschau(tester);
    // Ein einzelner Wurf kann zufällig den Standardkopf treffen; nach zehn
    // Würfen wäre das ein Fehler und kein Zufall.
    var geaendert = false;
    for (var i = 0; i < 10 && !geaendert; i++) {
      await tester.tap(find.text('Zufällig würfeln'));
      await tester.pumpAndSettle();
      geaendert = _vorschau(tester) != vorher;
    }
    expect(geaendert, isTrue);
  });
}
