/// update_check.dart – Prüft GitHub Releases auf eine neuere App-Version.
///
/// Portiert aus PilzBuddy: unauthentifizierter Call auf die öffentliche
/// Releases-API, Tag `v<version>` gegen die installierte Version verglichen,
/// APK-Asset als Download-Quelle für das In-App-Update (ota_update).
library;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Informationen über ein verfügbares Update von GitHub Releases.
class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
  });
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
final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/MacBuchi/FWApp/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final release = jsonDecode(response.body) as Map<String, dynamic>;
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
    );
  } catch (_) {
    return null; // Update-Check darf die App nie stören.
  }
});
