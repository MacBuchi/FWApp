/// lerngruppe_providers.dart – Lesesicht und Vorgänge der Lerngruppen
/// (Issue #136).
///
/// Gelesen wird DIREKT aus `lerngruppen`: Die Lese-Policy gibt genau die
/// Gruppen heraus, in denen man Mitglied ist — eine Filterung hier wäre
/// dieselbe Regel ein zweites Mal. Die Mitglieder kommen über die RPC
/// `lerngruppen_mitglieder_namen`, weil `profiles` nur die eigene Zeile
/// herausgibt (Begründung in `20260922210000_lerngruppen_namen.sql`).
/// Geschrieben wird ausschließlich über die drei RPCs; die Tabellen haben
/// keine Schreib-Policies.
///
/// ⚠️ Beendete Gruppen kommen MIT: Die Policy filtert das Datum nicht. Das
/// ist gewollt — der Bildschirm zeigt sie gedämpft, damit man sehen kann,
/// wer dabei war.
///
/// Manuelle Provider wie der Rest der Supabase-Anbindung (Supabase-Typen
/// vertragen keinen riverpod-Codegen, siehe core/sync/sync_providers.dart).
/// Kategorie nach CONTRIBUTING „Schichtung je Feature": keine
/// synchronisierte Entität, nichts davon liegt in Drift — deshalb Provider
/// plus Service statt Repository.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

/// Die eigenen Lerngruppen, unsortiert (sortiert wird mit dem Datum des
/// Bildschirms, siehe [sortiereLerngruppen]).
///
/// Leere Liste statt Fehler ohne Anmeldung, im Lokalmodus und auf einem
/// Server ohne die Migration — genau so sieht es auch für jemanden aus, der
/// noch in keiner Gruppe ist, und der Bildschirm erklärt den Rest.
final meineLerngruppenProvider = FutureProvider<List<Lerngruppe>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows = await client
        .from('lerngruppen')
        .select('id, gesamtwehr_id, name, code, laeuft_bis');
    return [
      for (final r in rows)
        Lerngruppe.fromJson((r as Map).cast<String, dynamic>()),
    ];
  } catch (e) {
    appLog.i('Lerngruppen nicht ladbar (Server ohne #136?)', error: e);
    return const [];
  }
});

/// Wer in der Gruppe ist, in Beitrittsreihenfolge.
final lerngruppenMitgliederProvider = FutureProvider.autoDispose
    .family<List<LerngruppenMitglied>, String>((ref, gruppeId) async {
      final client = ref.watch(supabaseClientProvider);
      final session = ref.watch(sessionStreamProvider).value;
      if (client == null || session == null) return const [];
      try {
        final rows =
            await client.rpc(
                  'lerngruppen_mitglieder_namen',
                  params: {'p_gruppe': gruppeId},
                )
                as List<dynamic>;
        return [
          for (final r in rows)
            LerngruppenMitglied.fromJson((r as Map).cast<String, dynamic>()),
        ];
      } catch (e) {
        appLog.i('Mitglieder der Lerngruppe nicht ladbar', error: e);
        return const [];
      }
    });

/// Übersetzt einen Fehler aus den RPCs für die Anzeige.
String lerngruppeFehler(Object fehler) => lerngruppeFehlerText(
  fehler is PostgrestException ? fehler.message : fehler.toString(),
);

final lerngruppeServiceProvider = Provider<LerngruppeService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : LerngruppeService(client, ref);
});

/// Gründen, beitreten, verlassen. Jeder Vorgang frischt danach die Liste auf.
class LerngruppeService {
  final SupabaseClient _client;
  final Ref _ref;

  LerngruppeService(this._client, this._ref);

  Future<Lerngruppe> gruende({
    required String gesamtwehrId,
    required String name,
    int wochen = kLerngruppenStandardWochen,
  }) async {
    final row = await _client.rpc(
      'erstelle_lerngruppe',
      params: {
        'p_gesamtwehr': gesamtwehrId,
        'p_name': name.trim(),
        'p_wochen': wochen,
      },
    );
    _ref.invalidate(meineLerngruppenProvider);
    return Lerngruppe.fromJson((row as Map).cast<String, dynamic>());
  }

  /// [code] muss schon normalisiert sein ([normalisiereCode]).
  Future<Lerngruppe> trittBei(String code) async {
    final row = await _client.rpc(
      'tritt_lerngruppe_bei',
      params: {'p_code': code},
    );
    _ref.invalidate(meineLerngruppenProvider);
    return Lerngruppe.fromJson((row as Map).cast<String, dynamic>());
  }

  Future<void> verlasse(String gruppeId) async {
    await _client.rpc('verlasse_lerngruppe', params: {'p_gruppe': gruppeId});
    _ref.invalidate(meineLerngruppenProvider);
  }
}
