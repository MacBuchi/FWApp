/// server_einrichten_screen_test.dart – Die zwei Bildschirme der
/// Server-Kopplung (Issue #238): einrichten per Adresse/QR und den
/// Einrichtungs-QR zeigen.
///
/// Holen, Prüfen, Speichern und Neustarten sind ersetzt — kein Netz im
/// Widget-Test. Was die echten Funktionen tun, prüft server_kopplung_test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/kopplung/data/kopplung_quelle.dart';
import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:fwapp/features/kopplung/presentation/providers/kopplung_providers.dart';
import 'package:fwapp/features/kopplung/presentation/screens/server_einrichten_screen.dart';
import 'package:fwapp/features/kopplung/presentation/screens/server_qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _musterstadt = ServerKopplung(
  name: 'Feuerwehr Musterstadt',
  url: 'https://api.musterstadt.de',
  anonKey: 'eyJ.test',
);

class _FakeDienste extends KopplungsDienste {
  final List<String> aufrufe = [];
  Object? holFehler;
  Object? pruefFehler;
  bool browser = false;
  String? name;

  @override
  Future<ServerKopplung> hole(Uri adresse) async {
    aufrufe.add('hole $adresse');
    if (holFehler != null) throw holFehler!;
    return _musterstadt;
  }

  @override
  Future<void> pruefe(ServerKopplung k) async {
    aufrufe.add('pruefe ${k.url}');
    if (pruefFehler != null) throw pruefFehler!;
  }

  @override
  Future<void> speichere(ServerKopplung k, ServerQuelle quelle) async =>
      aufrufe.add('speichere ${k.url} ${quelle.name}');

  @override
  bool neuStarten() {
    aufrufe.add('neustart');
    return browser;
  }

  @override
  Future<String?> gespeicherterName() async => name;
}

void main() {
  late AppDatabase db;
  late _FakeDienste dienste;

  setUp(() {
    db = createTestDatabase();
    dienste = _FakeDienste();
  });
  tearDown(() => db.close());

  Widget einrichten({bool mitQr = true}) => buildTestApp(
    db: db,
    home: ServerEinrichtenScreen(mitQr: mitQr),
    overrides: [kopplungsDiensteProvider.overrideWithValue(dienste)],
  );

  Future<void> adresseVerbinden(WidgetTester tester, String adresse) async {
    await tester.enterText(find.byType(TextField), adresse);
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pumpAndSettle();
  }

  testWidgets('im Browser kein QR-Weg, in der App schon', (tester) async {
    await tester.pumpWidget(einrichten(mitQr: false));
    await tester.pumpAndSettle();
    expect(find.text('QR-Code scannen'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(einrichten());
    await tester.pumpAndSettle();
    expect(find.text('QR-Code scannen'), findsOneWidget);
  });

  testWidgets('per Adresse: holen, nachfragen, prüfen, speichern — in der '
      'App mit Bitte um Neustart', (tester) async {
    await tester.pumpWidget(einrichten());
    await tester.pumpAndSettle();

    await adresseVerbinden(tester, 'feuerwehr-musterstadt.de');
    expect(dienste.aufrufe, [
      'hole https://feuerwehr-musterstadt.de/.well-known/fwapp.json',
    ]);
    // Vor dem Speichern: wohin, und die Warnung für Unveröffentlichtes.
    expect(find.text('Mit „Feuerwehr Musterstadt" verbinden?'), findsOneWidget);
    expect(find.textContaining('noch nicht veröffentlicht'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden').last);
    await tester.pumpAndSettle();

    expect(dienste.aufrufe.skip(1), [
      'pruefe https://api.musterstadt.de',
      'speichere https://api.musterstadt.de domain',
      'neustart',
    ]);
    expect(find.text('Fast geschafft'), findsOneWidget);
  });

  testWidgets('abbrechen in der Rückfrage speichert nichts', (tester) async {
    await tester.pumpWidget(einrichten());
    await tester.pumpAndSettle();
    await adresseVerbinden(tester, 'musterstadt.de');

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(dienste.aufrufe.where((a) => a.startsWith('speichere')), isEmpty);
  });

  testWidgets('antwortet der Server nicht, wird nichts gespeichert', (
    tester,
  ) async {
    dienste.pruefFehler = const KopplungFehler('gerade nicht erreichbar');
    await tester.pumpWidget(einrichten());
    await tester.pumpAndSettle();
    await adresseVerbinden(tester, 'musterstadt.de');
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden').last);
    await tester.pumpAndSettle();

    expect(find.text('gerade nicht erreichbar'), findsOneWidget);
    expect(dienste.aufrufe.where((a) => a.startsWith('speichere')), isEmpty);
    expect(find.text('Fast geschafft'), findsNothing);
  });

  testWidgets('keine Installation unter der Adresse: Satz im Feld', (
    tester,
  ) async {
    dienste.holFehler = const KopplungFehler(
      'Unter dieser Adresse ist keine FWApp-Installation eingerichtet.',
    );
    await tester.pumpWidget(einrichten());
    await tester.pumpAndSettle();
    await adresseVerbinden(tester, 'irgendwo.de');

    expect(find.textContaining('keine FWApp-Installation'), findsOneWidget);
    expect(find.textContaining('verbinden?'), findsNothing);
  });

  testWidgets('im Browser lädt die Seite neu statt um Neustart zu bitten', (
    tester,
  ) async {
    dienste.browser = true;
    await tester.pumpWidget(einrichten(mitQr: false));
    await tester.pumpAndSettle();
    await adresseVerbinden(tester, 'musterstadt.de');
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden').last);
    await tester.pumpAndSettle();

    expect(dienste.aufrufe.last, 'neustart');
    expect(find.text('Fast geschafft'), findsNothing);
  });

  testWidgets('der Einrichtungs-QR trägt genau den eingetragenen Server', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sync_enabled': true,
      'supabase_url': 'https://api.musterstadt.de/',
      'supabase_key': 'eyJ.test',
    });
    dienste.name = 'Feuerwehr Musterstadt';
    await tester.pumpWidget(
      buildTestApp(
        db: db,
        home: const ServerQrScreen(),
        overrides: [kopplungsDiensteProvider.overrideWithValue(dienste)],
      ),
    );
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, 'Einrichtungs-Code für Feuerwehr Musterstadt');
    expect(find.text('https://api.musterstadt.de'), findsOneWidget);
    expect(find.textContaining('Anmelden kann'), findsOneWidget);

    // Was im QR steht (QrImageView gibt seine Daten nicht heraus): der Code
    // aus dem Provider — und er muss sich wieder lesen lassen, genau so, wie
    // der Scanner auf dem neuen Gerät ihn liest.
    final k = containerOf(tester).read(eigeneKopplungProvider).value!;
    final gelesen = ServerKopplung.ausJson(k.alsJson());
    expect(gelesen.url, 'https://api.musterstadt.de');
    expect(gelesen.anonKey, 'eyJ.test');
    expect(gelesen.name, 'Feuerwehr Musterstadt');
  });
}
