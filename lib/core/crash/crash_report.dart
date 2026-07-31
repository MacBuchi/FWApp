/// crash_report.dart – Datenmodell und Fingerprint der Absturzberichte
/// (Issue #34), nach dem Bauplan „Route A" der Observability-Guideline.
///
/// Ohne I/O und ohne Flutter-Bindungen, damit Format, Fingerprint und die
/// PII-Regeln direkt prüfbar sind.
library;

import 'dart:convert';

/// Version des Ablageformats.
///
/// Ein persistiertes Format braucht eine Version, sonst ist jede Änderung ein
/// Datenverlust: Beim Lesen wird nach ihr verzweigt, unbekannte (neuere)
/// Versionen werden verworfen statt falsch gedeutet.
const kCrashFormatVersion = 1;

/// Stacktraces werden gekürzt. Die obersten Frames tragen die Information;
/// ein vollständiger Trace kann Dutzende Kilobyte haben.
const kMaxStackChars = 4000;

/// Ein festgehaltener Absturz.
///
/// ⚠️ **Was hier hineinkommt, kann in einem öffentlichen GitHub-Issue landen.**
/// Erlaubt sind App-Version, Plattform, OS-Version, Gerätemodell, Locale,
/// Stacktrace, Log-Vorgeschichte, Fingerprint und Zeitpunkt. **Niemals**
/// E-Mail, Nutzername, Token, JWT oder Pfade mit Benutzernamen —
/// `test/core/crash/crash_pii_test.dart` prüft das.
class CrashReport {
  /// Zeitpunkt in UTC.
  final DateTime time;

  /// `1.5.2 (Build 20)` — ohne die ist ein Bericht kaum auswertbar.
  final String appVersion;

  /// Woher der Fehler kam, z. B. `Flutter framework` oder `Async`.
  final String source;
  final String error;
  final String stackTrace;

  /// `Android 16 (SM-G991B)` o. Ä. — leer, wenn nicht ermittelbar.
  final String device;

  /// Sprache/Region, z. B. `de_DE`.
  final String locale;

  /// Die letzten Log-Zeilen vor dem Absturz, älteste zuerst.
  final List<String> log;

  /// Stabile Kennung gleichartiger Abstürze, siehe [crashFingerprint].
  final String fingerprint;

  const CrashReport({
    required this.time,
    required this.appVersion,
    required this.source,
    required this.error,
    required this.stackTrace,
    required this.fingerprint,
    this.device = '',
    this.locale = '',
    this.log = const [],
  });

  Map<String, dynamic> toJson() => {
        'v': kCrashFormatVersion,
        'time': time.toIso8601String(),
        'appVersion': appVersion,
        'source': source,
        'error': error,
        'stackTrace': stackTrace,
        'fingerprint': fingerprint,
        'device': device,
        'locale': locale,
        'log': log,
      };

  /// Liest einen Bericht. Liefert `null`, wenn der Eintrag unbrauchbar ist —
  /// ein kaputter Bericht darf den Start nicht blockieren.
  ///
  /// Legacy-tolerant: Berichte ohne `v` stammen aus v1.5.0/1.5.1 (vor der
  /// Formatversion) und haben weder Fingerprint noch Kontext. Sie werden
  /// gelesen statt weggeworfen — sie sind der Grund, warum jemand meldet.
  static CrashReport? fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    if (version is int && version > kCrashFormatVersion) return null;

    final time = DateTime.tryParse(json['time'] as String? ?? '');
    if (time == null) return null;

    final error = json['error'] as String? ?? '';
    final stack = json['stackTrace'] as String? ?? '';
    return CrashReport(
      time: time,
      appVersion: json['appVersion'] as String? ?? 'unbekannt',
      source: json['source'] as String? ?? 'unbekannt',
      error: error,
      stackTrace: stack,
      // Alte Berichte tragen keinen — nachträglich aus dem Inhalt bilden,
      // damit auch sie an der Dedupe teilnehmen.
      fingerprint:
          json['fingerprint'] as String? ?? crashFingerprint(error, stack),
      device: json['device'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      log: (json['log'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  /// Text für das GitHub-Issue bzw. die Zwischenablage.
  String toReportText() {
    final buffer = StringBuffer()
      ..writeln('Absturz vom ${time.toLocal()}')
      ..writeln('App-Version: $appVersion')
      ..writeln('Quelle: $source');
    if (device.isNotEmpty) buffer.writeln('Gerät: $device');
    if (locale.isNotEmpty) buffer.writeln('Sprache: $locale');
    buffer
      ..writeln('Kennung: $fingerprint')
      ..writeln()
      ..writeln(error)
      ..writeln()
      ..writeln(stackTrace);
    if (log.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Letzte Log-Zeilen davor:')
        ..writeAll(log.map((l) => '  $l'), '\n');
    }
    return buffer.toString();
  }
}

/// Kürzt einen Stacktrace auf [kMaxStackChars] und vermerkt das sichtbar,
/// damit niemand einen abgeschnittenen Trace für vollständig hält.
String truncateStack(String stack, {int max = kMaxStackChars}) {
  if (stack.length <= max) return stack;
  return '${stack.substring(0, max)}\n… (gekürzt)';
}

/// Stabile Kennung gleichartiger Abstürze: Fehlertyp plus die obersten
/// **eigenen** Stackframes.
///
/// Framework-Frames fliegen raus — sonst bekämen zwei völlig verschiedene
/// Fehler denselben Fingerprint, nur weil beide durch dieselbe Flutter-Schicht
/// laufen.
///
/// Gehasht mit **FNV-1a, nie `String.hashCode`**: Dessen Wert ist zwischen
/// Läufen und Dart-Versionen nicht stabil, und ein persistierter Hash, der
/// sich ändert, dedupliziert nichts mehr.
String crashFingerprint(String error, String stackTrace, {int frames = 4}) {
  // Fehlertyp ohne Meldung: „Bad state: Foo 42" und „Bad state: Foo 43" sind
  // derselbe Fall; die Zahl im Text darf sie nicht auseinanderziehen.
  final type = error.split(':').first.trim();

  final own = <String>[];
  for (final raw in const LineSplitter().convert(stackTrace)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (!line.contains('package:fwapp/')) continue;
    // Zeilen-/Spaltennummern raus: Eine verschobene Zeile ist derselbe Fehler.
    own.add(line.replaceAll(RegExp(r':\d+:\d+\)'), ')'));
    if (own.length >= frames) break;
  }
  // Kein eigener Frame (reiner Framework-Absturz): Dann trägt der Typ allein.
  return _fnv1a('$type|${own.join('|')}');
}

/// FNV-1a, 32 Bit, als 8-stelliger Hex-String.
String _fnv1a(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    // & 0xFFFFFFFF nach der Multiplikation: Dart-int ist 64 Bit, ohne die
    // Maske liefe der Hash aus dem 32-Bit-Raum und wäre nicht mehr FNV-1a.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
