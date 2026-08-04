/// profil_providers.dart – Eigener Anzeigename und eigener Avatar
/// (Nutzerkonzept Stufe ③, Issue #100).
///
/// Beides gehört DEM KONTO, nicht der Verwaltung: Geschrieben wird über
/// `mein_profil_setzen`, das kein Ziel-Konto kennt und immer auf
/// `auth.uid()` schreibt. Den Nutzernamen (die Anmeldung) vergibt weiterhin
/// der Kommandant über `admin-users` — das sind zwei verschiedene Dinge,
/// siehe Migration 20260804140000.
///
/// Manuelle Provider wie der Rest von core/sync.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Das eigene Profil, so wie es angezeigt wird.
class MeinProfil {
  /// Selbst gewählter Anzeigename; leer, solange keiner gesetzt ist.
  final String? anzeigename;

  /// Kennung aus dem Zugangszettel — die Rückfallebene für [name].
  final String? username;

  /// Der gespeicherte Avatar-Text; `null` = noch keiner gewählt.
  final String? avatarText;

  /// Kennt dieser Server die Profilspalten? Auf einem Alt-Server bleibt das
  /// `false`, und der Profil-Screen bietet das Speichern gar nicht erst an —
  /// besser als ein Knopf, der in eine Fehlermeldung läuft.
  final bool serverKenntProfil;

  const MeinProfil({
    this.anzeigename,
    this.username,
    this.avatarText,
    this.serverKenntProfil = false,
  });

  /// Was neben dem Kopf steht: der selbst gewählte Name, sonst der
  /// Nutzername, sonst gar nichts (der Aufrufer nimmt dann die Adresse).
  String? get name {
    final a = anzeigename?.trim();
    if (a != null && a.isNotEmpty) return a;
    final u = username?.trim();
    return u == null || u.isEmpty ? null : u;
  }

  /// Der Kopf. Ohne gespeicherten Wert der Standardkopf — jeder hat einen,
  /// niemand muss erst etwas auswählen, damit die Liste nicht grau ist.
  AvatarKonfiguration get avatar => AvatarKonfiguration.dekodiert(avatarText);

  bool get hatAvatar => avatarText != null && avatarText!.trim().isNotEmpty;
}

/// Das eigene Profil. `null` im Lokalmodus und abgemeldet.
final meinProfilProvider = FutureProvider<MeinProfil?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  final id = session.user.id;
  try {
    final row = await client
        .from('profiles')
        .select('username, anzeigename, avatar')
        .eq('id', id)
        .maybeSingle();
    return MeinProfil(
      anzeigename: row?['anzeigename'] as String?,
      username: row?['username'] as String?,
      avatarText: row?['avatar'] as String?,
      serverKenntProfil: true,
    );
  } catch (e) {
    // Alt-Server ohne die Spalten: Der Nutzername existiert seit Phase 4 und
    // ist dort das Einzige, was es zu zeigen gibt.
    appLog.i('Profilspalten nicht ladbar (Alt-Server?)', error: e);
    try {
      final row = await client
          .from('profiles')
          .select('username')
          .eq('id', id)
          .maybeSingle();
      return MeinProfil(username: row?['username'] as String?);
    } catch (e2) {
      appLog.i('Profil gar nicht ladbar', error: e2);
      return const MeinProfil();
    }
  }
});

final profilServiceProvider = Provider<ProfilService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : ProfilService(client, ref);
});

class ProfilService {
  final SupabaseClient _client;
  final Ref _ref;

  ProfilService(this._client, this._ref);

  /// Speichert beides in einem Aufruf — wer im Profil speichert, hat meist
  /// beides angefasst, und ein halb gespeichertes Profil wäre das schlechtere
  /// Ergebnis einer abgerissenen Verbindung.
  Future<void> speichere({
    required String anzeigename,
    required AvatarKonfiguration avatar,
  }) async {
    await _client.rpc('mein_profil_setzen', params: {
      'neuer_anzeigename': anzeigename.trim(),
      'neuer_avatar': avatar.kodiert,
    });
    _ref.invalidate(meinProfilProvider);
  }
}

/// Übersetzt die Absagen des Servers in einen Satz fürs Gerätehaus.
String profilFehlerText(Object fehler) {
  final roh = fehler.toString();
  if (roh.contains('name too long')) {
    return 'Der Anzeigename darf höchstens 40 Zeichen haben.';
  }
  if (roh.contains('name has control characters')) {
    return 'Der Anzeigename darf keine Zeilenumbrüche enthalten.';
  }
  if (roh.contains('avatar')) {
    return 'Dieser Avatar lässt sich nicht speichern. Bitte einen anderen '
        'wählen.';
  }
  if (roh.contains('mein_profil_setzen') ||
      roh.contains('does not exist') ||
      roh.contains('PGRST202')) {
    return 'Dieser Server kennt Profile noch nicht. Er muss zuerst '
        'aktualisiert werden.';
  }
  return roh;
}
