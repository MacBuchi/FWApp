/// auth_env_test.dart – Server-Einstellungen, die Features tragen
/// (Issue #118).
///
/// Drei Funktionen hingen an GoTrue-Variablen, die ausschließlich in
/// `~/supabase/docker-compose.override.yml` auf der VM standen. **Zwei
/// scheitern lautlos** — die englische Standardmail geht mit Link raus, ohne
/// dass am Aufruf etwas fehlschlägt. Dokumentation ist eine Erinnerung,
/// keine Prüfung; deshalb steht der Soll-Zustand jetzt in
/// `deploy/auth_env.json` und der Autodeploy hält ihn gegen den laufenden
/// Container.
///
/// Diese Datei prüft die Teile, die im Repo liegen: dass Manifest und
/// Betriebsdoku dasselbe sagen, dass kein Geheimnis hineinrutscht — und
/// dass der Abgleich im Autodeploy-Skript wirklich Abweichungen findet.
/// Letzteres läuft gegen den **tatsächlich ausgelieferten** Python-Block aus
/// dem Skript, nicht gegen eine Abschrift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _authEnvAus(String pfad) {
  final roh = jsonDecode(File(pfad).readAsStringSync()) as Map<String, dynamic>;
  final quelle = roh.containsKey('auth_env')
      ? roh['auth_env'] as Map<String, dynamic>
      : roh;
  return {
    for (final e in quelle.entries)
      if (!e.key.startsWith('_')) e.key: e.value as String,
  };
}

/// Schneidet den Python-Block zwischen `<<'MARKER'` und `MARKER` aus dem
/// Autodeploy-Skript. So läuft der Test gegen den Code, der auf der VM
/// wirklich ausgeführt wird.
String _pythonBlock(String skript, String marker) {
  final start = skript.indexOf("<<'$marker'");
  expect(start, greaterThan(-1), reason: 'Marker $marker nicht gefunden');
  final zeilenAnfang = skript.indexOf('\n', start) + 1;
  final ende = skript.indexOf('\n$marker\n', zeilenAnfang);
  expect(ende, greaterThan(-1), reason: 'Ende von $marker nicht gefunden');
  return skript.substring(zeilenAnfang, ende);
}

void main() {
  final authEnv = _authEnvAus('deploy/auth_env.json');
  final imManifest = _authEnvAus('deploy/manifest.json');

  group('die Quelle', () {
    test('das Manifest trägt genau, was in auth_env.json steht', () {
      // Das Manifest wird erzeugt; hier hängt, dass der Generator die neue
      // Sektion auch wirklich mitnimmt.
      expect(imManifest, authEnv);
      expect(authEnv, isNotEmpty);
    });

    test('enthält kein Geheimnis', () {
      // Die Datei liegt öffentlich im Repo. Der Generator bricht bei
      // verdächtigen Schlüsseln ab; dieser Test hält dieselbe Grenze fest,
      // damit sie nicht still gelockert wird.
      for (final k in authEnv.keys) {
        for (final wort in const [
          'KEY', 'SECRET', 'PASSWORD', 'TOKEN', 'DSN', 'SMTP_PASS',
        ]) {
          expect(k.toUpperCase().contains(wort), isFalse, reason: k);
        }
      }
    });

    test('alle Werte sind Text — auch die Schalter', () {
      // Umgebungsvariablen sind immer Zeichenketten. `true` als JSON-Boolean
      // käme im Container als „True" oder „1" an und der Abgleich meldete
      // ewig eine Abweichung.
      expect(authEnv['GOTRUE_MFA_TOTP_ENROLL_ENABLED'], 'true');
    });
  });

  test('die Betriebsdoku nennt dieselben Werte', () {
    // Genau die Lücke aus dem Issue: Die Doku beschreibt die Variablen,
    // niemand prüft sie. Jetzt tut es dieser Test — läuft eines von beidem
    // weg, fällt es hier auf und nicht erst an einer stillen Mail.
    final doku = File('docs/SERVER-SETUP.md').readAsStringSync();
    final zeilen = RegExp(r'^(GOTRUE_[A-Z0-9_]+):\s*(.+)$', multiLine: true);
    final ausDoku = <String, String>{};
    for (final m in zeilen.allMatches(doku)) {
      var wert = m.group(2)!.trim();
      if (wert.startsWith('"') && wert.endsWith('"')) {
        wert = wert.substring(1, wert.length - 1);
      }
      ausDoku[m.group(1)!] = wert;
    }
    expect(ausDoku, isNotEmpty, reason: 'keine GOTRUE-Zeile in der Doku?');
    expect(ausDoku, authEnv);
  });

  group('der Abgleich im Autodeploy', () {
    final skript = File('tool/vm/fwapp_autodeploy.sh').readAsStringSync();
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('authdrift'));
    tearDown(() => tmp.deleteSync(recursive: true));

    /// Führt den ausgelieferten Vergleichs-Block aus und liefert seine
    /// Ausgabe — eine Zeile je Abweichung, leer wenn alles stimmt.
    List<String> vergleiche(Map<String, String> soll, Map<String, String> ist) {
      final py = File('${tmp.path}/diff.py')
        ..writeAsStringSync(_pythonBlock(skript, 'AUTHDIFF'));
      final sollDatei = File('${tmp.path}/soll.txt')
        ..writeAsStringSync(
            soll.entries.map((e) => '${e.key}\t${e.value}').join('\n'));
      final istDatei = File('${tmp.path}/ist.txt')
        ..writeAsStringSync(
            ist.entries.map((e) => '${e.key}=${e.value}').join('\n'));
      final r = Process.runSync(
          'python3', [py.path, sollDatei.path, istDatei.path]);
      expect(r.exitCode, 0, reason: r.stderr.toString());
      return (r.stdout as String)
          .split('\n')
          .where((z) => z.trim().isNotEmpty)
          .toList();
    }

    test('stimmt alles, meldet er nichts', () {
      expect(vergleiche(authEnv, {...authEnv, 'PATH': '/usr/bin'}), isEmpty);
    });

    test('eine fehlende Variable wird gemeldet', () {
      // Der häufigste Fall: Beim Aufsetzen vergessen. Genau so lief die
      // Einladungsmail wochenlang englisch und mit Link.
      final ist = {...authEnv}..remove('GOTRUE_MAILER_TEMPLATES_INVITE');
      final treffer = vergleiche(authEnv, ist);
      expect(treffer, hasLength(1));
      expect(treffer.single, contains('GOTRUE_MAILER_TEMPLATES_INVITE'));
      expect(treffer.single, contains('FEHLT'));
    });

    test('ein abweichender Wert wird mit beiden Seiten gemeldet', () {
      final ist = {...authEnv, 'GOTRUE_MFA_TOTP_ENROLL_ENABLED': 'false'};
      final treffer = vergleiche(authEnv, ist);
      expect(treffer, hasLength(1));
      expect(treffer.single, contains('false'));
      expect(treffer.single, contains('true'));
    });

    test('Werte mit Leerzeichen und Doppelpunkt überstehen den Vergleich', () {
      // Betreffzeilen enthalten beides („{{ .Data.titel }}: Einladung").
      // Ein Trenner wie `:` oder ` ` hätte hier still danebengegriffen.
      const schluessel = 'GOTRUE_MAILER_SUBJECTS_INVITE';
      expect(authEnv[schluessel], contains(' '));
      expect(authEnv[schluessel], contains(':'));
      expect(vergleiche(authEnv, authEnv), isEmpty);
      expect(vergleiche(authEnv, {...authEnv, schluessel: 'FWApp: Einladung'}),
          hasLength(1));
    });

    test('zusätzliche Variablen auf dem Server stören nicht', () {
      // Der Container bringt Dutzende eigene mit. Gemeldet wird nur, was im
      // Manifest steht — sonst wäre der Bericht unlesbar.
      expect(
        vergleiche(authEnv, {...authEnv, 'GOTRUE_SITE_URL': 'https://x.de'}),
        isEmpty,
      );
    });
  });
}
