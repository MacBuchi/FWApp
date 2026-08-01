/// abteilung_providers.dart – Abteilungswahl (Issue #57 Phase 2).
///
/// Drei Zuständigkeiten, bewusst getrennt:
/// - [selectedAbteilungIdProvider]: Welche Abteilung zeigt die App gerade?
///   `null` heißt „die eigene" — das ist zugleich der Legacy-Zustand, in dem
///   die lokale Datenbank die angestammte Datei `fwapp.sqlite` behält.
///   Unveröffentlichte Arbeit von vor dem Update darf beim Umstieg nicht
///   verschwinden, deshalb bekommt NUR eine Schwester-Abteilung eine eigene
///   Datei.
/// - [myAbteilungIdProvider]: Heimat-Abteilung laut Server-Profil.
/// - [abteilungenProvider]: Alles, was RLS lesen lässt — die eigene plus die
///   Schwestern derselben Gesamtwehr (Entscheidung A, lesend).
///
/// Manuelle Provider wie der Rest von core/sync (Supabase-Typen vertragen
/// keinen riverpod-Codegen, siehe sync_providers.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider lebt in Riverpod 3 im legacy-Namespace.
import 'package:flutter_riverpod/legacy.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs-Schlüssel der gemerkten Auswahl (null/fehlend = eigene Abteilung).
const kSelectedAbteilungPref = 'selected_abteilung';

/// Aktuell angezeigte Abteilung; `null` = die eigene (und Legacy-Betrieb).
/// Startwert setzt main.dart aus den SharedPreferences; Umschalten läuft
/// über [switchAbteilung], damit Persistenz und Pull nicht vergessen werden.
final selectedAbteilungIdProvider = StateProvider<String?>((ref) => null);

/// Heimat-Abteilung des angemeldeten Nutzers (aus dem eigenen Profil).
/// `null`: nicht angemeldet, Lokalmodus oder Server ohne Mandanten-Schema.
final myAbteilungIdProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  try {
    final row = await client
        .from('profiles')
        .select('abteilung_id')
        .maybeSingle();
    return row?['abteilung_id'] as String?;
  } catch (e) {
    appLog.i('Heimat-Abteilung nicht ermittelbar (Legacy-Server?)', error: e);
    return null;
  }
});

/// Eine lesbare Abteilung samt Anzeige-Kontext.
class AbteilungInfo {
  final String id;
  final String name;
  final String status;

  /// Name der Gesamtwehr, wenn die Abteilung einer angehört.
  final String? gesamtwehrName;

  const AbteilungInfo({
    required this.id,
    required this.name,
    required this.status,
    this.gesamtwehrName,
  });
}

/// Alle Abteilungen, die RLS den Angemeldeten lesen lässt (eigene +
/// Schwestern der Gesamtwehr). Leer im Lokalmodus und auf Legacy-Servern —
/// die Auswahl-UI verschwindet dann von selbst.
final abteilungenProvider = FutureProvider<List<AbteilungInfo>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows = await client
        .from('abteilungen')
        .select('id, name, status, gesamtwehren(name)')
        .order('name');
    return [
      for (final r in rows)
        AbteilungInfo(
          id: r['id'] as String,
          name: r['name'] as String,
          status: r['status'] as String,
          gesamtwehrName:
              (r['gesamtwehren'] as Map<String, dynamic>?)?['name'] as String?,
        ),
    ];
  } catch (e) {
    appLog.i('Abteilungsliste nicht ladbar (Legacy-Server?)', error: e);
    return const [];
  }
});

/// Wechselt die angezeigte Abteilung — die EINZIGE Schreibstelle für die
/// Auswahl. Wer den StateProvider direkt setzt, verliert Persistenz und
/// Erst-Pull.
final abteilungSwitcherProvider =
    Provider<AbteilungSwitcher>((ref) => AbteilungSwitcher(ref));

class AbteilungSwitcher {
  final Ref _ref;
  AbteilungSwitcher(this._ref);

  /// Merken, Provider umstellen, Bestand der neuen Sicht ziehen.
  /// [id] = null wechselt zur eigenen Abteilung zurück.
  Future<void> switchTo(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(kSelectedAbteilungPref);
    } else {
      await prefs.setString(kSelectedAbteilungPref, id);
    }
    _ref.read(selectedAbteilungIdProvider.notifier).state = id;

    // Erst-Pull der neuen Sicht; scheitert offline leise — die (ggf. leere)
    // lokale Datei der Abteilung ist dann der ehrliche Stand.
    try {
      await _ref.read(syncServiceProvider)?.pullIfNewer(force: true);
    } catch (e) {
      appLog.w('Pull nach Abteilungswechsel fehlgeschlagen', error: e);
    }
  }
}
