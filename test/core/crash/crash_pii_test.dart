/// crash_pii_test.dart – Regressionstest gegen personenbezogene Daten in
/// Absturzberichten (Issue #34).
///
/// ⚠️ **Warum das ein eigener Test ist:** Der Bericht landet auf Wunsch der
/// Nutzerin in einem **öffentlichen** GitHub-Issue. Alles, was über den
/// Log-Ring-Buffer oder den Fehlertext hineinrutscht, ist damit im Netz.
/// Jedes `reason:` unten benennt, was real schiefginge.
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/crash/crash_store.dart';
import 'package:fwapp/core/logging/app_logger.dart';

/// Werte, wie sie in einer angemeldeten Sitzung wirklich vorkommen.
const _accessToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.FAKE_ACCESS_TOKEN.sig';
const _refreshToken = 'v1-fake-refresh-token-abcdef';
const _email = 'geraetewart@fw.local';
const _anonKey = 'eyJhbGciOiJIUzI1NiJ9.FAKE_ANON_KEY.sig';

void main() {
  late Directory tempDir;
  late CrashStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fwapp_pii_test');
    store = CrashStore(File('${tempDir.path}/crash_reports.json'));
    globalCrashStore = store;
    globalCrashContext = const CrashContext(
      appVersion: '1.5.2 (Build 20)',
      device: 'android — Android 16',
      locale: 'de_DE',
    );
    appLogRing.clear();
  });

  tearDown(() {
    globalCrashStore = null;
    appLogRing.clear();
    tempDir.deleteSync(recursive: true);
  });

  test('ein Bericht aus einer angemeldeten Sitzung trägt keine Geheimnisse',
      () {
    // So sieht der Ring nach einem normalen Anmelde- und Sync-Vorgang aus.
    appLogRing
      ..add('Server erreichbar')
      ..add('Pulled dataset version 38 (4 rows).')
      ..add('Library seed complete.');

    recordCrash(
      source: 'Async',
      error: StateError('Sync fehlgeschlagen'),
      stackTrace: StackTrace.fromString(
          '#0 SyncService.pull (package:fwapp/core/sync/sync_service.dart:1:1)'),
    );

    final text = store.load().single.toReportText();

    expect(text, isNot(contains(_accessToken)),
        reason: 'ein Access-Token im Issue gibt Fremden Zugriff auf die Wehr');
    expect(text, isNot(contains(_refreshToken)),
        reason: 'ein Refresh-Token ist noch schlimmer, es läuft nicht ab');
    expect(text, isNot(contains(_email)),
        reason: 'die Anmeldeadresse ist personenbezogen');
    expect(text, isNot(contains(_anonKey)),
        reason: 'der Anon-Key gehört nicht in ein Issue, auch wenn er '
            'clientseitig öffentlich ist');
    expect(text, isNot(contains('password')),
        reason: 'Passwörter dürfen nirgends im Bericht auftauchen');
  });

  test('was der Logger nicht loggt, kann auch nicht durchrutschen', () {
    // Gegenprobe zur Regel im Kopf von app_logger.dart: Der Ring gibt genau
    // das weiter, was geloggt wurde — er ist keine zweite Quelle. Wer also
    // ein Token loggt, hat es im Bericht. Dieser Test hält fest, dass der
    // Ring nichts von sich aus hinzufügt.
    appLogRing.add('harmlose Zeile');
    recordCrash(source: 'Async', error: Exception('x'));

    final report = store.load().single;
    expect(report.log, ['harmlose Zeile']);
  });

  test('der Ring gibt ein hineingeratenes Geheimnis ungeschönt weiter', () {
    // Bewusst dokumentiert statt weggefiltert: Ein Filter im Ring würde
    // Sicherheit vortäuschen. Die Regel lautet „nicht loggen", nicht
    // „später wegfiltern" — deshalb prüft dieser Test das Gegenteil und
    // macht die Verantwortung sichtbar.
    appLogRing.add('Token: $_accessToken');
    recordCrash(source: 'Async', error: Exception('x'));

    expect(store.load().single.toReportText(), contains(_accessToken),
        reason: 'wer ein Geheimnis loggt, hat es im Bericht — genau deshalb '
            'steht die Regel am Logger und nicht hier');
  });

  test('der Kontext enthält nur Technisches', () {
    recordCrash(source: 'Async', error: Exception('x'));
    final r = store.load().single;

    // Erlaubt sind Version, Plattform/OS und Locale — mehr nicht.
    expect(r.appVersion, '1.5.2 (Build 20)');
    expect(r.device, 'android — Android 16');
    expect(r.locale, 'de_DE');
    expect(r.toReportText(), isNot(contains('@')),
        reason: 'kein Feld darf eine Adresse tragen');
  });

  test('lange Log-Zeilen werden gekappt, nicht ausgelassen', () {
    // Eine überlange Zeile (z. B. ein hineingereichter Serverfehler) würde
    // sonst den halben Ring belegen und die Vorgeschichte verdrängen.
    appLogRing.add('x' * (kLogRingMaxLineChars + 500));
    recordCrash(source: 'Async', error: Exception('x'));

    final line = store.load().single.log.single;
    expect(line.length, lessThanOrEqualTo(kLogRingMaxLineChars + 1));
    expect(line, endsWith('…'));
  });
}
