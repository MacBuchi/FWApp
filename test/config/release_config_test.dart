/// release_config_test.dart – Konfigurations-Regressionstests für Fallen,
/// die ausschließlich im Release-Build zuschlagen.
///
/// Diese Tests lesen Konfigurationsdateien als Text und prüfen Einträge, die
/// im Debug-Lauf entweder automatisch ergänzt werden oder schlicht nicht
/// gebraucht werden. Genau deshalb fallen sie sonst erst beim Nutzer auf —
/// die FWApp hat das dreimal bezahlt:
///
///   * v1.3.1 – fehlende INTERNET-Permission: Release-App ohne jedes Netz.
///   * Issue #27 – fehlender VIEW/https-Eintrag: Browser-Fallback des
///     Updates scheiterte still auf Android 11+.
///   * Issue #39 – fehlender ProductionFilter: Release-Builds loggen nichts,
///     auch nicht aus den globalen Fehler-Handlern.
///
/// Der Geräte-Smoke-Test deckt manches davon ab, läuft aber nicht in CI.
/// Diese Tests tun es.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kommentare entfernen, damit ein auskommentierter Eintrag nicht als
/// vorhanden durchgeht.
String _withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

void main() {
  group('AndroidManifest.xml', () {
    late String manifest;

    setUpAll(() {
      manifest = _withoutXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );
    });

    test('INTERNET-Permission ist explizit deklariert', () {
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: 'Debug-Builds mergen die Permission automatisch, das '
            'Release-Manifest braucht sie explizit — sonst scheitert jede '
            'DNS-Auflösung mit "Failed host lookup" (v1.3.1).',
      );
    });

    test('In-App-Update: Permission, FileProvider und Pfade hängen zusammen',
        () {
      expect(
        manifest,
        contains('android.permission.REQUEST_INSTALL_PACKAGES'),
        reason: 'Ohne diese Permission darf ota_update das heruntergeladene '
            'APK nicht an den Android-Installer übergeben.',
      );
      expect(
        manifest,
        contains(r'${applicationId}.ota_update_provider'),
        reason: 'ota_update erwartet exakt diese FileProvider-Authority. '
            'Fehlt sie, stürzt die App nach abgeschlossenem Download ab.',
      );
      expect(
        manifest,
        contains('@xml/filepaths'),
        reason: 'Der FileProvider braucht seine Pfad-Definition.',
      );

      final filepaths = _withoutXmlComments(
        File('android/app/src/main/res/xml/filepaths.xml').readAsStringSync(),
      );
      expect(
        filepaths,
        contains('ota_update/'),
        reason: 'Ohne files-path auf ota_update/ kann der FileProvider das '
            'heruntergeladene APK nicht freigeben.',
      );
    });

    test('queries erlaubt das Auflösen von https-Links (Issue #27)', () {
      final queries =
          RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest);
      expect(queries, isNotNull, reason: 'Kein <queries>-Block im Manifest.');

      final block = queries!.group(1)!;
      expect(
        block,
        contains('android.intent.action.VIEW'),
        reason: 'Ohne VIEW/https-Intent sieht die App unter Android 11+ '
            'keinen Browser: launchUrl liefert still false und der '
            'Update-Fallback "Im Browser laden" läuft ins Leere.',
      );
      expect(block, contains('android:scheme="https"'));
    });

    test('Backup schließt die Supabase-Session aus (Issue #33)', () {
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/backup_rules"'),
        reason: 'Ohne eigene Regeln gilt allowBackup=true für alles — dann '
            'landet das Refresh-Token im Google-Konto des Nutzers.',
      );
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/full_backup_content"'),
        reason: 'dataExtractionRules greift erst ab Android 12; ältere '
            'Versionen brauchen fullBackupContent.',
      );

      for (final file in const [
        'android/app/src/main/res/xml/backup_rules.xml',
        'android/app/src/main/res/xml/full_backup_content.xml',
      ]) {
        final rules = _withoutXmlComments(File(file).readAsStringSync());
        expect(
          rules,
          contains('FlutterSharedPreferences.xml'),
          reason: '$file muss die Prefs ausschließen — dort legt '
              'supabase_flutter die Session inkl. Refresh-Token ab.',
        );
        expect(
          rules,
          isNot(contains('fwapp.sqlite')),
          reason: 'Die Datenbank soll bewusst IM Backup bleiben, sonst '
              'kostet ein Gerätewechsel den Lernfortschritt.',
        );
      }
    });
  });

  test('build.gradle.kts aktiviert Core Library Desugaring', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains('isCoreLibraryDesugaringEnabled = true'),
      reason: 'ota_update setzt Desugaring voraus — fehlt es, bricht schon '
          'der Gradle-Build.',
    );
    expect(gradle, contains('coreLibraryDesugaring('));
  });

  test('appLog setzt einen ProductionFilter (Issue #39)', () {
    final source = File('lib/core/logging/app_logger.dart').readAsStringSync();
    expect(
      source,
      contains('ProductionFilter()'),
      reason: 'Der Default DevelopmentFilter setzt sein shouldLog innerhalb '
          'eines assert-Blocks. Asserts fallen im Release weg, damit wird '
          'dort NICHTS geloggt — auch nicht aus den globalen Fehler-Handlern. '
          'Per Verhalten ist das nicht testbar: Im Test sind Asserts aktiv.',
    );
  });
}
