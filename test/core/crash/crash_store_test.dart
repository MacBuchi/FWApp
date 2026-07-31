/// crash_store_test.dart – Lokaler Absturzspeicher (Issue #34).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/crash/crash_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

CrashReport report(int n, {String stack = 'stack'}) => CrashReport(
      time: DateTime.utc(2026, 7, 31, 12, n),
      appVersion: '1.4.9 (Build 17)',
      source: 'Async',
      error: 'Fehler $n',
      stackTrace: stack,
    );

void main() {
  group('Serialisierung', () {
    test('überlebt eine Runde encode/decode verlustfrei', () {
      final decoded = decodeCrashReports(encodeCrashReports([report(1)]));
      expect(decoded, hasLength(1));
      expect(decoded.single.error, 'Fehler 1');
      expect(decoded.single.appVersion, '1.4.9 (Build 17)');
      expect(decoded.single.source, 'Async');
      expect(decoded.single.time, DateTime.utc(2026, 7, 31, 12, 1));
    });

    test('behält nur die jüngsten Berichte', () {
      final many = [for (var i = 1; i <= 10; i++) report(i)];
      final decoded = decodeCrashReports(encodeCrashReports(many));
      expect(decoded, hasLength(kMaxStoredCrashes));
      // Die ältesten fliegen raus, die jüngsten bleiben.
      expect(decoded.first.error, 'Fehler 8');
      expect(decoded.last.error, 'Fehler 10');
    });

    test('verwirft kaputte Daten, statt zu werfen', () {
      // Ein unlesbarer Eintrag darf den App-Start nicht blockieren.
      expect(decodeCrashReports('kein json'), isEmpty);
      expect(decodeCrashReports('{"nicht":"eine liste"}'), isEmpty);
      expect(decodeCrashReports(null), isEmpty);
      expect(decodeCrashReports(''), isEmpty);
    });

    test('überspringt einzelne Einträge ohne brauchbaren Zeitstempel', () {
      const raw = '[{"time":"unsinn","error":"a"},'
          '{"time":"2026-07-31T12:00:00.000Z","error":"b"}]';
      final decoded = decodeCrashReports(raw);
      expect(decoded, hasLength(1));
      expect(decoded.single.error, 'b');
    });
  });

  group('truncateStack', () {
    test('lässt kurze Stacktraces unangetastet', () {
      expect(truncateStack('kurz'), 'kurz');
    });

    test('kürzt lange und macht das sichtbar', () {
      final long = 'x' * 100;
      final cut = truncateStack(long, max: 10);
      expect(cut, startsWith('x' * 10));
      expect(cut, contains('gekürzt'));
      expect(cut.length, lessThan(long.length));
    });
  });

  group('CrashStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('legt Berichte ab und liest sie wieder', () async {
      final store = CrashStore(await SharedPreferences.getInstance());
      expect(store.load(), isEmpty);

      await store.record(report(1));
      await store.record(report(2));

      final loaded = store.load();
      expect(loaded, hasLength(2));
      expect(loaded.map((r) => r.error), ['Fehler 1', 'Fehler 2']);
    });

    test('kappt auch über mehrere Aufrufe hinweg', () async {
      final store = CrashStore(await SharedPreferences.getInstance());
      for (var i = 1; i <= 6; i++) {
        await store.record(report(i));
      }
      expect(store.load(), hasLength(kMaxStoredCrashes));
      expect(store.load().last.error, 'Fehler 6');
    });

    test('clear() räumt vollständig ab', () async {
      final store = CrashStore(await SharedPreferences.getInstance());
      await store.record(report(1));
      await store.clear();
      expect(store.load(), isEmpty);
    });
  });

  group('recordCrash', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => globalCrashStore = null);

    test('schreibt über den globalen Store', () async {
      globalCrashStore = CrashStore(await SharedPreferences.getInstance());
      await recordCrash(
        source: 'Flutter framework',
        error: StateError('kaputt'),
        stackTrace: StackTrace.fromString('frame 1'),
        appVersion: '1.4.9 (Build 17)',
      );
      final loaded = globalCrashStore!.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.error, contains('kaputt'));
      expect(loaded.single.source, 'Flutter framework');
      expect(loaded.single.stackTrace, 'frame 1');
    });

    test('tut nichts (und wirft nicht), wenn kein Store bereitsteht', () async {
      // Passiert im echten Start, wenn die Prefs noch nicht geladen sind. Der
      // Fehlerpfad darf dann keinen zweiten Fehler erzeugen.
      globalCrashStore = null;
      await expectLater(
        recordCrash(
          source: 'Async',
          error: Exception('egal'),
          appVersion: 'unbekannt',
        ),
        completes,
      );
    });

    test('kürzt lange Stacktraces beim Ablegen', () async {
      globalCrashStore = CrashStore(await SharedPreferences.getInstance());
      await recordCrash(
        source: 'Async',
        error: Exception('x'),
        stackTrace: StackTrace.fromString('y' * (kMaxStackChars + 500)),
        appVersion: '1.4.9',
      );
      final stored = globalCrashStore!.load().single.stackTrace;
      expect(stored.length, lessThan(kMaxStackChars + 100));
      expect(stored, contains('gekürzt'));
    });
  });

  group('toReportText', () {
    test('enthält Version, Quelle, Fehler und Stacktrace', () {
      final text = report(1, stack: 'frame A').toReportText();
      expect(text, contains('1.4.9 (Build 17)'));
      expect(text, contains('Async'));
      expect(text, contains('Fehler 1'));
      expect(text, contains('frame A'));
    });
  });
}
