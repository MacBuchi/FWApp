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
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
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

  Widget host({MeinProfil? profil}) => buildTestApp(
        db: db,
        home: const ProfilScreen(),
        overrides: [
          supabaseClientProvider.overrideWithValue(null),
          sessionStreamProvider.overrideWith((ref) => Stream.value(null)),
          meinProfilProvider.overrideWith((ref) async =>
              profil ??
              const MeinProfil(username: 'wart.stadt', serverKenntProfil: true)),
          profilServiceProvider.overrideWithValue(service),
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
