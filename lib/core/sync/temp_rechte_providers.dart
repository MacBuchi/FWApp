/// temp_rechte_providers.dart – Temporäre Gerätewart-Rechte
/// (Nutzerkonzept Stufe ③, Issue #100).
///
/// Der Gerätewart erteilt sie aktiv, mit Ablauf. Der Sinn ist der
/// Übungsbetrieb: Ein Truppführer soll Geräte und Fächer anlegen können,
/// ohne dass daraus eine dauerhafte Rolle wird.
///
/// ⚠️ **Das wirkt nur online.** Der Client fragt die Rechte beim Server ab;
/// im Funkloch-Keller bleibt es beim zuletzt bekannten Stand. Deshalb steht
/// im Nutzerkonzept: vor der Übung erteilen, nicht mittendrin.
///
/// ⚠️ Und es schaltet **nur das Bearbeiten** frei, nie das Verwalten — die
/// Grenze zieht der Server (`darf_mitglieder_verwalten` kennt temporäre
/// Rechte bewusst nicht), hier wird sie nur nicht aufgeweicht.
///
/// Manuelle Provider wie der Rest von core/sync (Supabase-Typen vertragen
/// keinen riverpod-Codegen, siehe sync_providers.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Eine Zeile aus dem Protokoll — laufend, abgelaufen oder zurückgezogen.
class TemporaeresRecht {
  final String id;
  final String userId;
  final String abteilungId;
  final DateTime laeuftAb;
  final DateTime erteiltAm;
  final String? erteiltVon;
  final DateTime? zurueckgezogenAm;

  const TemporaeresRecht({
    required this.id,
    required this.userId,
    required this.abteilungId,
    required this.laeuftAb,
    required this.erteiltAm,
    this.erteiltVon,
    this.zurueckgezogenAm,
  });

  /// Gilt gerade. Dieselbe Frage, die `hat_temporaeres_recht` in SQL stellt —
  /// die Uhr des Geräts kann falsch gehen, deshalb entscheidet am Ende immer
  /// der Server; hier geht es nur um die Anzeige.
  bool get laeuft =>
      zurueckgezogenAm == null && laeuftAb.isAfter(DateTime.now());

  static TemporaeresRecht ausZeile(Map<String, dynamic> r) => TemporaeresRecht(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        abteilungId: r['abteilung_id'] as String,
        laeuftAb: DateTime.parse(r['laeuft_ab'] as String).toLocal(),
        erteiltAm: DateTime.parse(r['erteilt_am'] as String).toLocal(),
        erteiltVon: r['erteilt_von'] as String?,
        zurueckgezogenAm: r['zurueckgezogen_am'] == null
            ? null
            : DateTime.parse(r['zurueckgezogen_am'] as String).toLocal(),
      );
}

const _spalten =
    'id, user_id, abteilung_id, laeuft_ab, erteilt_am, erteilt_von, '
    'zurueckgezogen_am';

/// Die eigenen LAUFENDEN Rechte: Abteilung → Ablaufzeitpunkt.
///
/// `null` heißt „nicht beantwortbar" (Lokalmodus, nicht angemeldet, oder ein
/// Server ohne diese Tabelle). Der Aufrufer muss dann so tun, als gäbe es
/// keine — ein angenommenes Recht wäre schlimmer als ein fehlendes.
final meineTemporaerenRechteProvider =
    FutureProvider<Map<String, DateTime>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  try {
    final rows = await client
        .from('temporaere_rechte')
        .select(_spalten)
        .isFilter('zurueckgezogen_am', null);
    final jetzt = DateTime.now();
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        if (TemporaeresRecht.ausZeile(r).laeuftAb.isAfter(jetzt))
          r['abteilung_id'] as String:
              DateTime.parse(r['laeuft_ab'] as String).toLocal(),
    };
  } catch (e) {
    appLog.i('Temporäre Rechte nicht ladbar (Alt-Server?)', error: e);
    return null;
  }
});

/// Alles, was in dieser Abteilung je erteilt wurde — das Protokoll für die
/// Nutzerverwaltung. Die Lese-Policy gibt nur her, wer dort erteilen darf.
final temporaereRechteDerAbteilungProvider = FutureProvider.autoDispose
    .family<List<TemporaeresRecht>, String>((ref, abteilungId) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows = await client
        .from('temporaere_rechte')
        .select(_spalten)
        .eq('abteilung_id', abteilungId)
        .order('erteilt_am', ascending: false)
        .limit(50);
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        TemporaeresRecht.ausZeile(r),
    ];
  } catch (e) {
    appLog.i('Protokoll der temporären Rechte nicht ladbar', error: e);
    return const [];
  }
});

/// Der voreingestellte Ablauf: Tagesende auf DIESEM Gerät.
///
/// ⚠️ Bewusst hier und nicht in SQL: „bis Tagesende" hängt an der Zeitzone
/// des Nutzers, und die kennt der Server nicht. Er prüft nur die Grenzen
/// (in der Zukunft, höchstens 24 Stunden).
///
/// Kurz vor Mitternacht wäre „Tagesende" ein Recht von zehn Minuten — das
/// hilft bei einer Übung niemandem. Darum in dem Fall die nächste volle
/// Stunde des Folgetags, aber nie über die 24-Stunden-Grenze des Servers.
DateTime tagesendeAblauf([DateTime? jetzt]) {
  final n = jetzt ?? DateTime.now();
  final mitternacht = DateTime(n.year, n.month, n.day, 23, 59);
  if (mitternacht.difference(n).inMinutes >= 60) return mitternacht;
  return n.add(const Duration(hours: 4));
}

final tempRechteServiceProvider = Provider<TempRechteService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : TempRechteService(client, ref);
});

class TempRechteService {
  final SupabaseClient _client;
  final Ref _ref;

  TempRechteService(this._client, this._ref);

  void _aktualisiere(String abteilungId) {
    _ref.invalidate(meineTemporaerenRechteProvider);
    _ref.invalidate(temporaereRechteDerAbteilungProvider(abteilungId));
    _ref.invalidate(meineMitgliedschaftenProvider);
  }

  Future<void> erteile(String userId, String abteilungId, DateTime bis) async {
    await _client.rpc('temp_recht_erteilen', params: {
      'ziel_user': userId,
      'ziel_abteilung': abteilungId,
      // Immer in UTC übergeben: Der Server rechnet in timestamptz, ein
      // lokaler Zeitstempel ohne Zone käme dort um Stunden verschoben an.
      'bis': bis.toUtc().toIso8601String(),
    });
    _aktualisiere(abteilungId);
  }

  Future<void> zieheZurueck(String rechtId, String abteilungId) async {
    await _client.rpc('temp_recht_zurueckziehen', params: {'ziel': rechtId});
    _aktualisiere(abteilungId);
  }
}

/// Übersetzt die Absagen des Servers in einen Satz fürs Gerätehaus.
String tempRechtFehlerText(Object fehler) {
  final roh = fehler.toString();
  if (roh.contains('temporaeres recht erteilen')) {
    return 'Temporäre Rechte erteilt nur, wer in dieser Abteilung selbst '
        'schreiben darf.';
  }
  if (roh.contains('not a member')) {
    return 'Diese Person gehört nicht zu dieser Abteilung. Erst aufnehmen, '
        'dann Rechte erteilen.';
  }
  if (roh.contains('already permanent')) {
    return 'Diese Person darf hier ohnehin schon dauerhaft schreiben.';
  }
  if (roh.contains('expiry too far away')) {
    return 'Temporäre Rechte gelten höchstens 24 Stunden.';
  }
  if (roh.contains('expiry must be in the future')) {
    return 'Der Ablauf muss in der Zukunft liegen.';
  }
  if (roh.contains('not found')) {
    return 'Dieses Recht gibt es nicht mehr.';
  }
  return roh;
}
