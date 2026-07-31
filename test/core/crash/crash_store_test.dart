/// crash_store_test.dart – Lokaler Absturzspeicher (Issue #34) nach dem
/// Bauplan „Route A" der Observability-Guideline.
library;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/crash/crash_report.dart';
import 'package:fwapp/core/crash/crash_store.dart';
import 'package:fwapp/core/logging/app_logger.dart';

CrashReport report(
  int n, {
  String stack = 'stack',
  String? fingerprint,
  DateTime? time,
}) =>
    CrashReport(
      time: time ?? DateTime.utc(2026, 7, 31, 12, n),
      appVersion: '1.5.2 (Build 20)',
      source: 'Async',
      error: 'Fehler $n',
      stackTrace: stack,
      fingerprint: fingerprint ?? 'fp$n',
    );

void main() {
  late Directory tempDir;
  late CrashStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fwapp_crash_test');
    store = CrashStore(File('${tempDir.path}/crash_reports.json'));
    globalCrashStore = store;
    globalCrashContext = const CrashContext(appVersion: '1.5.2 (Build 20)');
    appLogRing.clear();
  });

  tearDown(() {
    globalCrashStore = null;
    tempDir.deleteSync(recursive: true);
  });

  group('Serialisierung', () {
    test('überlebt eine Runde encode/decode verlustfrei', () {
      final decoded = decodeCrashReports(encodeCrashReports([
        CrashReport(
          time: DateTime.utc(2026, 7, 31, 12),
          appVersion: '1.5.2 (Build 20)',
          source: 'Async',
          error: 'Fehler',
          stackTrace: 'stack',
          fingerprint: 'abc12345',
          device: 'android — Android 16',
          locale: 'de_DE',
          log: const ['erste Zeile', 'zweite Zeile'],
        ),
      ]));
      expect(decoded, hasLength(1));
      final r = decoded.single;
      expect(r.error, 'Fehler');
      expect(r.fingerprint, 'abc12345');
      expect(r.device, 'android — Android 16');
      expect(r.locale, 'de_DE');
      expect(r.log, ['erste Zeile', 'zweite Zeile']);
    });

    test('behält nur die jüngsten Berichte', () {
      final many = [for (var i = 1; i <= 30; i++) report(i)];
      final decoded = decodeCrashReports(encodeCrashReports(many));
      expect(decoded, hasLength(kMaxStoredCrashes));
      expect(decoded.last.error, 'Fehler 30');
    });

    test('verwirft kaputte Daten, statt zu werfen', () {
      expect(decodeCrashReports('kein json'), isEmpty);
      expect(decodeCrashReports('{"nicht":"eine liste"}'), isEmpty);
      expect(decodeCrashReports(null), isEmpty);
      expect(decodeCrashReports(''), isEmpty);
    });

    test('liest Berichte ohne Formatversion (v1.5.0/1.5.1) weiter', () {
      // Legacy-Toleranz: Diese Berichte sind der Grund, warum jemand meldet —
      // sie wegzuwerfen wäre der schlechteste Zeitpunkt für Strenge.
      const legacy = '[{"time":"2026-07-31T12:00:00.000Z",'
          '"appVersion":"1.5.0 (Build 18)","source":"Async",'
          '"error":"Bad state: kaputt",'
          '"stackTrace":"#0 x (package:fwapp/a.dart:1:1)"}]';
      final decoded = decodeCrashReports(legacy);
      expect(decoded, hasLength(1));
      expect(decoded.single.appVersion, '1.5.0 (Build 18)');
      // Fingerprint wird nachträglich gebildet, damit auch alte Berichte an
      // der Dedupe teilnehmen.
      expect(decoded.single.fingerprint, isNotEmpty);
    });

    test('überspringt Einträge aus einem neueren Format', () {
      final raw = jsonEncode([
        {'v': kCrashFormatVersion + 1, 'time': '2026-07-31T12:00:00.000Z'},
        {
          'v': kCrashFormatVersion,
          'time': '2026-07-31T12:01:00.000Z',
          'error': 'lesbar',
        },
      ]);
      final decoded = decodeCrashReports(raw);
      expect(decoded, hasLength(1));
      expect(decoded.single.error, 'lesbar');
    });

    test('überspringt Einträge ohne brauchbaren Zeitstempel', () {
      const raw = '[{"time":"unsinn","error":"a"},'
          '{"time":"2026-07-31T12:00:00.000Z","error":"b"}]';
      expect(decodeCrashReports(raw).single.error, 'b');
    });
  });

  group('CrashStore (Datei)', () {
    test('legt Berichte ab und liest sie wieder', () {
      expect(store.load(), isEmpty);
      store.recordSync(report(1));
      store.recordSync(report(2));
      expect(store.load().map((r) => r.error), ['Fehler 1', 'Fehler 2']);
    });

    test('schreibt synchron — die Datei steht sofort nach dem Aufruf', () {
      // Der Kern der Übung: Ein Bericht muss den sofortigen Prozesstod
      // überstehen. Ein asynchroner Write wäre hier noch nicht auf Platte.
      store.recordSync(report(1));
      expect(store.file.existsSync(), isTrue);
      expect(store.file.readAsStringSync(), contains('Fehler 1'));
    });

    test('kappt auch über mehrere Aufrufe hinweg', () {
      for (var i = 1; i <= 25; i++) {
        store.recordSync(report(i));
      }
      expect(store.load(), hasLength(kMaxStoredCrashes));
      expect(store.load().last.error, 'Fehler 25');
    });

    test('clear() räumt vollständig ab', () {
      store.recordSync(report(1));
      store.clear();
      expect(store.load(), isEmpty);
      expect(store.file.existsSync(), isFalse);
    });

    test('liefert bei fehlender Datei eine leere Liste', () {
      expect(
          CrashStore(File('${tempDir.path}/gibtsnicht.json')).load(), isEmpty);
    });
  });

  group('recordCrash', () {
    test('schreibt über den globalen Store, mit Kontext und Log', () {
      appLogRing.add('etwas vorher passiert');
      globalCrashContext = const CrashContext(
        appVersion: '1.5.2 (Build 20)',
        device: 'android — Android 16',
        locale: 'de_DE',
      );

      recordCrash(
        source: 'Flutter framework',
        error: StateError('kaputt'),
        stackTrace: StackTrace.fromString('#0 f (package:fwapp/a.dart:3:4)'),
      );

      final loaded = store.load();
      expect(loaded, hasLength(1));
      final r = loaded.single;
      expect(r.error, contains('kaputt'));
      expect(r.source, 'Flutter framework');
      expect(r.appVersion, '1.5.2 (Build 20)');
      expect(r.device, 'android — Android 16');
      expect(r.locale, 'de_DE');
      expect(r.fingerprint, isNotEmpty);
      expect(r.log, contains('etwas vorher passiert'));
    });

    test('tut nichts (und wirft nicht), wenn kein Store bereitsteht', () {
      globalCrashStore = null;
      expect(
        () => recordCrash(source: 'Async', error: Exception('egal')),
        returnsNormally,
      );
    });

    test('kürzt lange Stacktraces beim Ablegen', () {
      recordCrash(
        source: 'Async',
        error: Exception('x'),
        stackTrace: StackTrace.fromString('y' * (kMaxStackChars + 500)),
      );
      final stored = store.load().single.stackTrace;
      expect(stored.length, lessThan(kMaxStackChars + 100));
      expect(stored, contains('gekürzt'));
    });
  });

  group('dedupeCrashes', () {
    test('behält je Fingerprint den jüngsten Bericht', () {
      // Eine Absturzschleife darf nicht als „20 Probleme" erscheinen.
      final deduped = dedupeCrashes([
        report(1, fingerprint: 'aa', time: DateTime.utc(2026, 7, 31, 10)),
        report(2, fingerprint: 'aa', time: DateTime.utc(2026, 7, 31, 11)),
        report(3, fingerprint: 'bb', time: DateTime.utc(2026, 7, 31, 12)),
      ]);
      expect(deduped, hasLength(2));
      expect(deduped.map((r) => r.fingerprint), ['aa', 'bb']);
      expect(deduped.first.error, 'Fehler 2', reason: 'der jüngste bleibt');
    });

    test('sortiert nach Zeit', () {
      final deduped = dedupeCrashes([
        report(1, fingerprint: 'bb', time: DateTime.utc(2026, 7, 31, 12)),
        report(2, fingerprint: 'aa', time: DateTime.utc(2026, 7, 31, 10)),
      ]);
      expect(deduped.map((r) => r.fingerprint), ['aa', 'bb']);
    });

    test('leere Liste bleibt leer', () {
      expect(dedupeCrashes(const []), isEmpty);
    });
  });

  group('toReportText', () {
    test('enthält Version, Quelle, Kennung, Fehler und Stacktrace', () {
      final text = CrashReport(
        time: DateTime.utc(2026, 7, 31, 12),
        appVersion: '1.5.2 (Build 20)',
        source: 'Async',
        error: 'Bad state: kaputt',
        stackTrace: '#0 f (package:fwapp/a.dart:3:4)',
        fingerprint: 'abc12345',
        device: 'android — Android 16',
        locale: 'de_DE',
        log: const ['vorher passiert'],
      ).toReportText();

      expect(text, contains('1.5.2 (Build 20)'));
      expect(text, contains('Async'));
      expect(text, contains('abc12345'));
      expect(text, contains('Bad state: kaputt'));
      expect(text, contains('package:fwapp/a.dart'));
      expect(text, contains('android — Android 16'));
      expect(text, contains('vorher passiert'));
    });

    test('lässt leere Felder weg statt leere Zeilen zu schreiben', () {
      final text = report(1).toReportText();
      expect(text, isNot(contains('Gerät:')));
      expect(text, isNot(contains('Sprache:')));
      expect(text, isNot(contains('Letzte Log-Zeilen')));
    });
  });
}
