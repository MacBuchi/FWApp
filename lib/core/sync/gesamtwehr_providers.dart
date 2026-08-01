/// gesamtwehr_providers.dart – Gesamtwehr und Verbindungen (Issue #57 Phase 3).
///
/// Vier Vorgänge, alle als RPC auf dem Server (die Tabellen haben bewusst
/// keine Schreib-Policies, siehe `20260801120000_gesamtwehr_verbindungen.sql`):
/// gründen, weitere Abteilung anlegen, Anschluss beantragen, entscheiden.
/// Dieser Client hält nur die Lesesicht darauf und übersetzt die Fehler.
///
/// Manuelle Provider wie der Rest von core/sync (Supabase-Typen vertragen
/// keinen riverpod-Codegen, siehe sync_providers.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

/// Eine Gesamtwehr, wie sie in der Auswahlliste erscheint.
class GesamtwehrInfo {
  final String id;
  final String name;
  const GesamtwehrInfo({required this.id, required this.name});
}

/// Die eigene Aufstellung: Abteilung und — falls vorhanden — ihre Klammer.
class MeineOrganisation {
  final String abteilungId;
  final String abteilungName;

  /// 'pending' | 'active' | 'rejected'. Nur `active` darf veröffentlichen.
  final String status;
  final String? gesamtwehrId;
  final String? gesamtwehrName;

  const MeineOrganisation({
    required this.abteilungId,
    required this.abteilungName,
    required this.status,
    this.gesamtwehrId,
    this.gesamtwehrName,
  });

  bool get verbunden => gesamtwehrId != null;
  bool get freigegeben => status == 'active';
}

/// Eine offene Anfrage aus Sicht des entscheidenden Admins.
class VerbindungsAnfrage {
  final String id;
  final String abteilungId;
  final String abteilungName;
  final String? nachricht;
  final DateTime? gestelltAm;

  const VerbindungsAnfrage({
    required this.id,
    required this.abteilungId,
    required this.abteilungName,
    this.nachricht,
    this.gestelltAm,
  });
}

/// Der eigene Antrag aus Sicht der anfragenden Abteilung.
class EigenerAntrag {
  final String id;
  final String gesamtwehrId;
  final String status;
  final String? antwort;

  const EigenerAntrag({
    required this.id,
    required this.gesamtwehrId,
    required this.status,
    this.antwort,
  });

  bool get laeuft => status == 'pending';
}

/// Eigene Abteilung samt Gesamtwehr. `null` im Lokalmodus, ohne Login oder
/// auf einem Server ohne Mandanten-Schema.
final meineOrganisationProvider =
    FutureProvider<MeineOrganisation?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  final meine = await ref.watch(myAbteilungIdProvider.future);
  if (meine == null) return null;
  try {
    final row = await client
        .from('abteilungen')
        .select('id, name, status, gesamtwehr_id, gesamtwehren(name)')
        .eq('id', meine)
        .maybeSingle();
    if (row == null) return null;
    return MeineOrganisation(
      abteilungId: row['id'] as String,
      abteilungName: row['name'] as String,
      status: row['status'] as String,
      gesamtwehrId: row['gesamtwehr_id'] as String?,
      gesamtwehrName:
          (row['gesamtwehren'] as Map<String, dynamic>?)?['name'] as String?,
    );
  } catch (e) {
    appLog.i('Eigene Abteilung nicht ladbar (Legacy-Server?)', error: e);
    return null;
  }
});

/// Alle Gesamtwehren der Instanz — die Liste, aus der man eine zum Anschluss
/// wählt. Für Angemeldete ohne Einschränkung lesbar (es sind nur Namen).
final gesamtwehrenProvider = FutureProvider<List<GesamtwehrInfo>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows =
        await client.from('gesamtwehren').select('id, name').order('name');
    return [
      for (final r in rows)
        GesamtwehrInfo(id: r['id'] as String, name: r['name'] as String),
    ];
  } catch (e) {
    appLog.i('Gesamtwehren nicht ladbar (Legacy-Server?)', error: e);
    return const [];
  }
});

/// Offene Anfragen an die eigene Gesamtwehr. Kommt über eine RPC, weil die
/// anfragende Abteilung noch keine Schwester ist und RLS ihren Namen deshalb
/// nicht herausgibt — genau darüber wird ja gerade entschieden.
final offeneAnfragenProvider =
    FutureProvider<List<VerbindungsAnfrage>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows =
        await client.rpc('offene_verbindungsanfragen') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        VerbindungsAnfrage(
          id: r['id'] as String,
          abteilungId: r['abteilung_id'] as String,
          abteilungName: r['abteilung_name'] as String,
          nachricht: r['nachricht'] as String?,
          gestelltAm: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ),
    ];
  } catch (e) {
    appLog.i('Offene Anfragen nicht ladbar', error: e);
    return const [];
  }
});

/// Der jüngste eigene Antrag, damit die anfragende Seite ihren Stand sieht.
final eigenerAntragProvider = FutureProvider<EigenerAntrag?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  final meine = await ref.watch(myAbteilungIdProvider.future);
  if (meine == null) return null;
  try {
    final row = await client
        .from('gesamtwehr_anfragen')
        .select('id, gesamtwehr_id, status, decided_note')
        .eq('abteilung_id', meine)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return EigenerAntrag(
      id: row['id'] as String,
      gesamtwehrId: row['gesamtwehr_id'] as String,
      status: row['status'] as String,
      antwort: row['decided_note'] as String?,
    );
  } catch (e) {
    appLog.i('Eigener Antrag nicht ladbar', error: e);
    return null;
  }
});

/// Übersetzt die (englischen, technischen) Server-Meldungen in einen Satz,
/// den ein Gerätewart im Gerätehaus versteht. Unbekanntes bleibt im Original —
/// eine falsche Beruhigung wäre schlimmer als eine fremde Meldung.
String gesamtwehrFehlerText(Object fehler) {
  final roh = fehler is PostgrestException ? fehler.message : fehler.toString();
  if (roh.contains('permission denied')) {
    return 'Dafür fehlt die Berechtigung — das darf nur ein Admin der '
        'Gesamtwehr.';
  }
  if (roh.contains('already belongs')) {
    return 'Diese Abteilung gehört bereits zu einer Gesamtwehr.';
  }
  if (roh.contains('gesamtwehr required')) {
    return 'Dafür braucht es zuerst eine Gesamtwehr — gründe sie oder tritt '
        'einer bei.';
  }
  if (roh.contains('already pending')) {
    return 'Es läuft bereits ein Antrag. Warte die Entscheidung ab.';
  }
  if (roh.contains('already decided')) {
    return 'Über diesen Antrag wurde schon entschieden.';
  }
  if (roh.contains('name required')) return 'Bitte einen Namen eingeben.';
  if (roh.contains('no abteilung assigned')) {
    return 'Dein Konto hängt an keiner Abteilung. Bitte beim Admin melden.';
  }
  if (roh.contains('gesamtwehr not found')) {
    return 'Diese Gesamtwehr gibt es nicht mehr.';
  }
  return roh;
}

final gesamtwehrServiceProvider = Provider<GesamtwehrService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : GesamtwehrService(client, ref);
});

/// Die vier schreibenden Vorgänge. Jeder frischt danach genau die Sichten
/// auf, die er verändert hat — eine Abteilung mehr heißt auch: eine Zeile
/// mehr im Abteilungs-Picker.
class GesamtwehrService {
  final SupabaseClient _client;
  final Ref _ref;

  GesamtwehrService(this._client, this._ref);

  void _aktualisiereSichten() {
    _ref.invalidate(meineOrganisationProvider);
    _ref.invalidate(gesamtwehrenProvider);
    _ref.invalidate(offeneAnfragenProvider);
    _ref.invalidate(eigenerAntragProvider);
    _ref.invalidate(abteilungenProvider);
  }

  Future<String> gruendeGesamtwehr(String name) async {
    final id = await _client.rpc('create_gesamtwehr', params: {'name': name});
    _aktualisiereSichten();
    return id as String;
  }

  Future<String> legeAbteilungAn(String name) async {
    final id = await _client.rpc('create_abteilung', params: {'name': name});
    _aktualisiereSichten();
    return id as String;
  }

  Future<void> beantrageVerbindung(String gesamtwehrId,
      {String? nachricht}) async {
    await _client.rpc('request_gesamtwehr_verbindung', params: {
      'ziel': gesamtwehrId,
      if (nachricht != null && nachricht.trim().isNotEmpty)
        'nachricht': nachricht.trim(),
    });
    _aktualisiereSichten();
  }

  Future<void> entscheide(String anfrageId,
      {required bool freigeben, String? nachricht}) async {
    await _client.rpc('decide_gesamtwehr_verbindung', params: {
      'anfrage': anfrageId,
      'freigeben': freigeben,
      if (nachricht != null && nachricht.trim().isNotEmpty)
        'nachricht': nachricht.trim(),
    });
    _aktualisiereSichten();
  }
}
