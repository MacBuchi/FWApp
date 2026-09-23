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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/domain/wertung.dart';
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

/// Die Aufgabe der laufenden Woche. `null` ohne Server, für Nichtmitglieder
/// und auf einem Server ohne die Wertungs-Migration.
final lerngruppeWochenaufgabeProvider = FutureProvider.autoDispose
    .family<Wochenaufgabe?, String>((ref, gruppeId) async {
      final client = ref.watch(supabaseClientProvider);
      final session = ref.watch(sessionStreamProvider).value;
      if (client == null || session == null) return null;
      try {
        return await _holeAufgabe(client, gruppeId);
      } catch (e) {
        appLog.i('Wochenaufgabe nicht ladbar (Server ohne #232?)', error: e);
        return null;
      }
    });

Future<Wochenaufgabe?> _holeAufgabe(
  SupabaseClient client,
  String gruppeId,
) async {
  final rows =
      await client.rpc(
            'lerngruppe_wochenaufgabe',
            params: {'p_gruppe': gruppeId},
          )
          as List<dynamic>;
  if (rows.isEmpty) return null;
  return Wochenaufgabe.fromJson((rows.first as Map).cast<String, dynamic>());
}

/// Alle gemeldeten Werte der Gruppe, über alle Wochen — die Lese-Policy gibt
/// sie nur Mitgliedern heraus.
final lerngruppenWertungenProvider = FutureProvider.autoDispose
    .family<List<Wertung>, String>((ref, gruppeId) async {
      final client = ref.watch(supabaseClientProvider);
      final session = ref.watch(sessionStreamProvider).value;
      if (client == null || session == null) return const [];
      try {
        final rows = await client
            .from('lerngruppen_wertungen')
            .select('user_id, woche, wert')
            .eq('gruppe_id', gruppeId);
        return [
          for (final r in rows)
            Wertung.fromJson((r as Map).cast<String, dynamic>()),
        ];
      } catch (e) {
        appLog.i('Wertungen nicht ladbar (Server ohne #232?)', error: e);
        return const [];
      }
    });

/// Meldet nach jeder gespeicherten Runde den Wochenwert für alle laufenden
/// Gruppen. Wird in der App-Wurzel per `ref.listen` am Leben gehalten.
///
/// Der Anstoß ist der Strom der lokalen Ergebnistabelle — und nicht ein
/// Aufruf in jedem der fünf Spielbildschirme: Ein sechster Modus würde sonst
/// still nicht melden. Der Strom liefert auch einmal beim Start; so kommt
/// eine Runde, die ohne Netz gespielt wurde, beim nächsten Start nach oben.
final lerngruppenAutoMeldungProvider = Provider<void>((ref) {
  final dienst = ref.watch(lerngruppeServiceProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (dienst == null || session == null) return;
  final db = ref.watch(appDatabaseProvider);

  // Zwei Runden kurz hintereinander sollen nicht zwei Läufe parallel
  // starten; der zweite Anstoß wird nachgeholt, nicht verworfen.
  var laeuft = false;
  var nochmal = false;
  Future<void> lauf() async {
    if (laeuft) {
      nochmal = true;
      return;
    }
    laeuft = true;
    try {
      do {
        nochmal = false;
        await dienst.meldeWochenwerte();
      } while (nochmal);
    } catch (e) {
      appLog.i('Wochenwerte nicht gemeldet (offline?)', error: e);
    } finally {
      laeuft = false;
    }
  }

  final sub = db.quizDao.watchAll().listen((_) => unawaited(lauf()));
  ref.onDispose(() => unawaited(sub.cancel()));
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

  /// Rechnet den eigenen Wochenwert für jede laufende Gruppe aus den lokalen
  /// Runden und meldet ihn (Regeln in `wertung.dart`).
  ///
  /// Liest die Gruppen direkt und nicht über [meineLerngruppenProvider]:
  /// `ref.read(provider.future)` ohne Zuhörer wird in Riverpod 3 nie fertig
  /// (AGENTS.md), und dieser Aufruf kommt aus dem Hintergrund.
  Future<int> meldeWochenwerte() async {
    final db = _ref.read(appDatabaseProvider);
    final heute = DateTime.now();
    final rows = await _client
        .from('lerngruppen')
        .select('id, gesamtwehr_id, name, code, laeuft_bis');
    final gemeldet = await meldeAlleWochenwerte(
      gruppen: [
        for (final r in rows)
          () {
            final g = Lerngruppe.fromJson((r as Map).cast<String, dynamic>());
            return (id: g.id, laeuft: g.laeuftAm(heute));
          }(),
      ],
      aufgabe: (id) => _holeAufgabe(_client, id),
      runden:
          (seit) async => [
            for (final r in await db.quizDao.getSeit(seit))
              (
                quizType: r.quizType,
                score: r.score,
                total: r.total,
                playedAt: r.playedAt,
              ),
          ],
      melde:
          (id, modus, wert) => _client.rpc(
            'melde_lerngruppen_wert',
            params: {
              'p_gruppe': id,
              'p_modus': modus.schluessel,
              'p_wert': wert,
            },
          ),
      beiFehler:
          (id, e) =>
              appLog.i('Wochenwert für Lerngruppe nicht gemeldet', error: e),
    );
    if (gemeldet > 0) _ref.invalidate(lerngruppenWertungenProvider);
    return gemeldet;
  }
}
