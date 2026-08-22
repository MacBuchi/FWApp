/// update_check.dart – Prüft GitHub Releases auf eine neuere App-Version.
///
/// Portiert aus PilzBuddy: unauthentifizierter Call auf die öffentliche
/// Releases-API, Tag `v<version>` gegen die installierte Version verglichen,
/// APK-Asset als Download-Quelle für das In-App-Update (ota_update).
library;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_check.g.dart';

/// Läuft der Update-Weg auf diesem Gerät überhaupt?
///
/// Nur die per APK verteilte Android-App aktualisiert sich selbst; die
/// Web-App ist durch die No-Cache-Header beim nächsten Neuladen aktuell.
bool get updateChecksApply =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Informationen über ein verfügbares Update von GitHub Releases.
class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  /// Ein noch nicht freigegebener Stand (Issue #169). Das Banner sagt es
  /// dazu: Wer eine Vorabversion installiert, soll das vorher wissen und
  /// nicht hinterher merken.
  final bool isPrerelease;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
    this.isPrerelease = false,
  });
}

/// Schlüssel des Vorab-Kanals. Liegt bewusst hier und nicht bei den übrigen
/// Einstellungen: Der Schalter gehört zum Update-Weg und darf nur dort
/// gelten, wo [updateChecksApply] gilt.
const _kPrereleaseUpdates = 'prerelease_updates';

/// Bekommt dieses Gerät auch Vorabversionen angeboten? (Issue #169, Vorbild
/// PilzBuddy #269 und MitFahrBar.)
///
/// Der Riegel steht HIER und nicht nur in der Oberfläche: Wo der Update-Weg
/// gar nicht läuft, ist der Schalter aus — sonst ließe er sich umlegen, ohne
/// dass je etwas passieren kann.
///
/// Gilt nur für dieses Gerät. Der Vorab-Kanal ist eine Entscheidung über das
/// eigene Handy, keine über die Wehr: Wer 25 Kameraden zwangsweise in
/// ungetestete Stände schickt, hat kein Testgerät, sondern ein Problem.
@riverpod
class PrereleaseUpdates extends _$PrereleaseUpdates {
  @override
  Future<bool> build() async {
    if (!updateChecksApply) return false;
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(_kPrereleaseUpdates) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kPrereleaseUpdates, value);
    state = AsyncValue.data(value);
  }
}

/// Der erste VERÖFFENTLICHTE Eintrag einer Release-Liste — Vorabversionen
/// eingeschlossen, Entwürfe nicht.
///
/// GitHub liefert die Liste absteigend nach Erstellungszeit, genommen wird
/// also der jüngste Stand. Ein Entwurf ist keiner: Seine Dateien sind nicht
/// öffentlich abrufbar, der Download liefe ins Leere und das Banner nennte
/// eine Version, die es für niemanden gibt.
Map<String, dynamic>? firstPublishedRelease(List<dynamic> releases) {
  for (final entry in releases) {
    if (entry is! Map<String, dynamic>) continue;
    if (entry['draft'] == true) continue;
    return entry;
  }
  return null;
}

/// Zerlegt `MAJOR.MINOR.PATCH` in drei Zahlen.
///
/// Toleriert die Zusätze, die real vorkommen: ein Build-Suffix (`1.4.9+17`),
/// einen Pre-Release-Teil (`1.5.1-rc1`) und ein führendes `v` (`v1.4.9`).
/// Liefert `null`, wenn daraus keine drei Zahlen werden — der Aufrufer
/// entscheidet dann, was ein unlesbarer Wert bedeutet, statt still `0` zu
/// erhalten.
///
/// Vorher wurde `1.5.1-rc1` zu `[1, 5, 0]` verrechnet: `int.tryParse('1-rc1')`
/// ergibt `null`, und der Fallback `?? 0` machte daraus eine *kleinere*
/// Version. Folgenlos, solange nur `MAJOR.MINOR.PATCH+BUILD` verwendet wird —
/// aber das Mindestversions-Gate (Issue #35) darf sich darauf nicht verlassen.
List<int>? parseVersion(String raw) {
  var v = raw.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  // Build-Metadaten und Pre-Release abschneiden: beide sind für die
  // Vorrang-Frage hier ohne Belang.
  final plus = v.indexOf('+');
  if (plus >= 0) v = v.substring(0, plus);
  final dash = v.indexOf('-');
  if (dash >= 0) v = v.substring(0, dash);

  // 1–3 Segmente: `2` und `1.4` bleiben wie bisher gültig und werden zu
  // 2.0.0 bzw. 1.4.0 aufgefüllt. Alles darüber ist kein MAJOR.MINOR.PATCH.
  final parts = v.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final out = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part.trim());
    if (n == null || n < 0) return null;
    out.add(n);
  }
  while (out.length < 3) {
    out.add(0);
  }
  return out;
}

/// `true`, wenn [latest] eine neuere Version als [current] ist
/// (numerischer Vergleich je Segment, z. B. 1.10.0 > 1.9.2).
///
/// Ist eine der beiden Seiten unlesbar, lautet die Antwort `false` — es wird
/// dann also **kein** Update angeboten. Ein Fehlalarm wäre hier schlimmer als
/// ein verpasster Hinweis.
bool isNewerVersion(String latest, String current) {
  final l = parseVersion(latest);
  final c = parseVersion(current);
  if (l == null || c == null) return false;
  for (var i = 0; i < 3; i++) {
    if (l[i] != c[i]) return l[i] > c[i];
  }
  return false;
}

/// Fragt das neueste GitHub-Release ab und vergleicht mit der installierten
/// Version. Nur relevant für die Android-App — die Web-App ist durch die
/// No-Cache-Header beim nächsten Reload immer aktuell.
/// Liefert `null`, wenn kein Update verfügbar ist oder der Check fehlschlägt.
///
/// Der Kanal (Issue #169) entscheidet ausschließlich über die ADRESSE:
/// `…/releases/latest` liefert grundsätzlich kein Prerelease, `…/releases`
/// die ganze Liste. Alles danach — Versionsvergleich, APK-Suche, „Was ist
/// neu", der Dialog — ist für beide Kanäle dasselbe. Zwei Fassungen wären
/// zwei Antworten auf „ist das ein Update", und der Unterschied fiele erst
/// dem Tester auf.
final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (!updateChecksApply) return null;
  final vorab = await ref.watch(prereleaseUpdatesProvider.future);
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await http.get(
      Uri.parse(vorab
          ? 'https://api.github.com/repos/MacBuchi/FWApp/releases?per_page=10'
          : 'https://api.github.com/repos/MacBuchi/FWApp/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final release = vorab
        ? firstPublishedRelease(decoded as List<dynamic>)
        : decoded as Map<String, dynamic>;
    if (release == null) return null;
    final tag = (release['tag_name'] as String? ?? '');
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latest.isEmpty || !isNewerVersion(latest, packageInfo.version)) {
      return null;
    }

    final assets = release['assets'] as List<dynamic>? ?? const [];
    final apk = assets
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String? ?? '').endsWith('.apk'));
    if (apk.isEmpty) return null;

    return UpdateInfo(
      latestVersion: latest,
      downloadUrl: apk.first['browser_download_url'] as String,
      releaseNotes: release['body'] as String?,
      isPrerelease: release['prerelease'] == true,
    );
  } catch (_) {
    return null; // Update-Check darf die App nie stören.
  }
});
