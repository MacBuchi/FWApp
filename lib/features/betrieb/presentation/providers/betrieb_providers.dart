/// betrieb_providers.dart – Anbindung der KreisDatenMeister-Konsole und
/// der zwei Stellen, an denen alle anderen etwas davon merken: die
/// Kontaktzeile auf der Login-Seite und der Hinweis „stillgelegt"
/// (Issue #101).
///
/// Manuelle Provider wie der Rest der Supabase-Anbindung (Supabase-Typen
/// vertragen keinen riverpod-Codegen, siehe core/sync/sync_providers.dart).
/// Kategorie nach CONTRIBUTING „Schichtung je Feature": keine
/// synchronisierte Entität, nichts davon liegt in Drift — Provider plus
/// Service statt Repository.
///
/// ⚠️ Wer die Konsole benutzen darf, entscheidet der SERVER
/// (`ist_betreiber()` in jeder `kdm_*`-Funktion). [istBetreiberProvider]
/// steuert nur, ob die App den Eintrag überhaupt anbietet.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/betrieb/domain/betrieb.dart';
import 'package:fwapp/features/settings/presentation/providers/user_admin_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Bin ich der KreisDatenMeister dieser Installation? `false` ohne Server,
/// ohne Anmeldung und auf einem Server ohne die Migration.
final istBetreiberProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return false;
  try {
    return await client.rpc('ist_betreiber') == true;
  } catch (e) {
    appLog.i('Betreiber-Status nicht ladbar (Server ohne #101?)', error: e);
    return false;
  }
});

/// Die öffentliche Kontaktzeile für die Login-Seite. Braucht KEINE
/// Anmeldung — genau dort wird sie gelesen, bevor es ein Konto gibt.
final installationKontaktProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  try {
    final kontakt = await client.rpc('installation_kontakt') as String?;
    final sauber = kontakt?.trim();
    return sauber == null || sauber.isEmpty ? null : sauber;
  } catch (e) {
    appLog.i('Kontaktzeile nicht ladbar (Server ohne #101?)', error: e);
    return null;
  }
});

/// Ist die eigene Gesamtwehr stillgelegt? `false`, solange es niemand
/// sicher weiß — ein Hinweis, der fälschlich „gesperrt" sagt, wäre schlimmer
/// als einer, der fehlt: Der Server lehnt ohnehin ab.
final eigeneWehrStillgelegtProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final org = await ref.watch(meineOrganisationProvider.future);
  final gesamtwehr = org?.gesamtwehrId;
  if (client == null || gesamtwehr == null) return false;
  try {
    final zeile =
        await client
            .from('gesamtwehren')
            .select('stillgelegt_am')
            .eq('id', gesamtwehr)
            .maybeSingle();
    return zeile?['stillgelegt_am'] != null;
  } catch (e) {
    appLog.i('Stilllegung nicht abfragbar (Server ohne #101?)', error: e);
    return false;
  }
});

/// Alle Gesamtwehren der Installation. Fehler kommen hier bewusst durch —
/// die Konsole soll sagen, warum sie leer ist, statt eine leere Liste zu
/// zeigen, die wie „keine Wehren" aussieht.
final kdmGesamtwehrenProvider = FutureProvider.autoDispose<List<KdmWehr>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  final rows = await client.rpc('kdm_gesamtwehren') as List<dynamic>;
  return [
    for (final r in rows) KdmWehr.fromJson((r as Map).cast<String, dynamic>()),
  ];
});

final betriebServiceProvider = Provider<BetriebService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : BetriebService(client, ref);
});

/// Die schreibenden Vorgänge der Konsole. Jeder frischt danach die
/// Übersicht auf.
class BetriebService {
  final SupabaseClient _client;
  final Ref _ref;

  BetriebService(this._client, this._ref);

  /// Legt die Wehr samt erster Abteilung an und lädt den ersten
  /// Kommandanten ein.
  ///
  /// Gibt die Kennung der neuen Wehr zurück. Scheitert die Einladung, steht
  /// die Wehr trotzdem — der Fehler kommt als [EinladungFehlgeschlagen]
  /// heraus, damit die Konsole sagen kann „angelegt, aber nicht eingeladen"
  /// statt so zu tun, als sei nichts passiert.
  Future<String> legeWehrAn({
    required String wehr,
    required String abteilung,
    required String kommandantMail,
    String? kommandantName,
  }) async {
    final roh =
        await _client.rpc(
              'kdm_lege_gesamtwehr_an',
              params: {'p_name': wehr.trim(), 'p_abteilung': abteilung.trim()},
            )
            as List<dynamic>;
    _ref.invalidate(kdmGesamtwehrenProvider);
    final zeile = (roh.single as Map).cast<String, dynamic>();
    final wehrId = zeile['gesamtwehr_id'] as String;
    try {
      await ladeKommandantenEin(
        abteilungId: zeile['abteilung_id'] as String,
        mail: kommandantMail,
        name: kommandantName,
      );
    } catch (e) {
      throw EinladungFehlgeschlagen(wehrId, e);
    }
    return wehrId;
  }

  /// Der bestehende Mailweg der Nutzerverwaltung — Vorlage, Brücke und
  /// Zustellauskunft gelten damit auch hier. Das Recht dazu prüft die
  /// Datenbank (`einladung_anlegen`).
  Future<void> ladeKommandantenEin({
    required String abteilungId,
    required String mail,
    String? name,
  }) async {
    await invokeAdminUsers(_client, {
      'action': 'invite',
      'email': mail.trim(),
      if (name != null && name.trim().isNotEmpty) 'anzeigename': name.trim(),
      'abteilung_id': abteilungId,
      'role': 'admin',
      'als_kommandant': true,
    });
    _ref.invalidate(kdmGesamtwehrenProvider);
  }

  /// Notfall und Aussperr-Schutz: vorhandenes Konto ernennen, sonst
  /// einladen (Regel in [kommandantHinzufuegen]).
  Future<KommandantWeg> fuegeKommandantHinzu({
    required String gesamtwehrId,
    required String abteilungId,
    required String mail,
    String? name,
  }) async {
    final weg = await kommandantHinzufuegen(
      ernenne:
          () => _client.rpc(
            'kdm_ernenne_kommandant',
            params: {'p_gesamtwehr': gesamtwehrId, 'p_email': mail.trim()},
          ),
      ladeEin:
          () => ladeKommandantenEin(
            abteilungId: abteilungId,
            mail: mail,
            name: name,
          ),
    );
    _ref.invalidate(kdmGesamtwehrenProvider);
    return weg;
  }

  Future<void> setzeStillgelegt(String gesamtwehrId, bool still) async {
    await _client.rpc(
      'kdm_stilllegen',
      params: {'p_gesamtwehr': gesamtwehrId, 'p_still': still},
    );
    _ref.invalidate(kdmGesamtwehrenProvider);
  }
}

/// Die Wehr steht, nur die Einladung ist nicht rausgegangen.
class EinladungFehlgeschlagen implements Exception {
  final String wehrId;
  final Object ursache;
  const EinladungFehlgeschlagen(this.wehrId, this.ursache);

  @override
  String toString() =>
      'Die Wehr ist angelegt, aber die Einladung ging nicht raus: '
      '${betriebFehlerText(ursache)} — über „Kommandant hinzufügen" erneut '
      'versuchen.';
}
