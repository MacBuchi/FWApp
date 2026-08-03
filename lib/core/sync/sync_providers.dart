/// sync_providers.dart – Riverpod providers for Supabase client, auth state,
/// role (admin/member), and the SyncService. Written as manual providers
/// (riverpod_generator cannot emit code for supabase_flutter's types).
library;
import 'dart:async' show TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider lebt in Riverpod 3 im legacy-Namespace.
import 'package:flutter_riverpod/legacy.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/equipment_type_sync.dart';
import 'package:fwapp/core/sync/image_sync_service.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:fwapp/core/sync/temp_rechte_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart'
    show supabaseStorageBaseUrl, supabaseStorageHeaders;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Set from main(): whether Supabase.initialize() succeeded this launch.
/// Changing the sync settings requires an app restart to take effect.
final supabaseReadyProvider = Provider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) =>
    ref.watch(supabaseReadyProvider) ? Supabase.instance.client : null);

/// Auth session, updating on sign-in/sign-out.
final sessionStreamProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange
      .map((event) => event.session)
      .distinct((a, b) => a?.user.id == b?.user.id);
});

/// Synchroner Blick auf die Sitzung — bewusst ein Callback und kein
/// `Provider<bool>`.
///
/// Ein gecachter bool würde nach dem Anmelden veralten: `currentSession` ist
/// keine Riverpod-Abhängigkeit, es gäbe also nichts, was ihn ungültig macht.
/// Der Router-Guard liest deshalb bei jedem Redirect frisch. Als Callback
/// bleibt er zugleich in Widget-Tests überschreibbar, ohne einen echten
/// SupabaseClient bauen zu müssen.
///
/// Warum nicht [sessionStreamProvider]? Der startet als `AsyncLoading` — jeder
/// Kaltstart eines angemeldeten Nutzers flöge damit erst auf die Anmeldung.
/// `Supabase.initialize` stellt die gespeicherte Sitzung dagegen VOR `runApp`
/// wieder her (ohne Ablaufprüfung), sodass dieser Blick ab dem ersten Frame
/// stimmt — und offline stehen bleibt, statt auszusperren.
final signedInReaderProvider = Provider<bool Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client?.auth.currentSession != null;
});

/// Läuft gerade ein Passwort-Zurücksetzen (Issue #57 Phase 4, Etappe 2)?
///
/// `verifyOTP` erzeugt eine gültige Sitzung, BEVOR das neue Passwort gesetzt
/// ist. Ohne dieses Flag würde der Router den Anmelde-Screen in genau diesem
/// Moment abräumen — die Person wäre in der App, ohne ihr Passwort zu kennen,
/// und der halbe Vorgang bliebe stehen. Solange es gesetzt ist, bleibt
/// `/login` erlaubt; der Screen setzt es selbst zurück (auch im Fehlerfall).
final recoveryPendingProvider = StateProvider<bool>((ref) => false);

/// Spiegel-Rolle aus profiles.role — seit Nutzerkonzept Stufe 1 nur noch
/// die Rückfallebene für Alt-Server; die Wahrheit sind die Mitgliedschaften
/// (membership_providers.dart). Null, wenn abgemeldet.
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  final row = await client
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .maybeSingle();
  return row?['role'] as String?;
});

/// Gate for all editing UI — seit Nutzerkonzept Stufe 1 (Issue #98) gilt
/// das Schreibrecht JE ABTEILUNG:
/// - Lokalmodus (kein Server): volle Kontrolle.
/// - Schreibrolle (admin/geraetewart) als Mitgliedschaft in der GERADE
///   ANGEZEIGTEN Abteilung — oder Feuerwehrkommandant ihrer Gesamtwehr.
/// - Alt-Server ohne Mitgliedschaften: alte Regel (Spiegel-Rolle,
///   Schwester-Sicht immer nur lesend).
/// Der Server prüft dasselbe in can_publish_abteilung — hier wird nur die
/// UI ausgeblendet, nicht das Recht durchgesetzt.
final canEditProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return true;
  final mitgliedschaften = ref.watch(meineMitgliedschaftenProvider).value;
  if (mitgliedschaften == null) {
    // Alt-Server oder noch am Laden: Regel von Issue #57 Phase 2.
    final selected = ref.watch(selectedAbteilungIdProvider);
    if (selected != null) {
      final own = ref.watch(myAbteilungIdProvider).value;
      if (selected != own) return false;
    }
    final role = ref.watch(currentUserRoleProvider).value;
    return role == 'admin' || role == 'geraetewart';
  }

  final selected = ref.watch(selectedAbteilungIdProvider) ??
      ref.watch(myAbteilungIdProvider).value;
  if (selected == null) {
    // Heimat (noch) unbekannt — direkt nach dem Anmelden, bevor das
    // Profil da ist. Eine Schreibrolle irgendwo genügt hier: Die Sicht
    // IST in dem Moment die Heimat.
    return mitgliedschaften.values
        .any((r) => r == 'admin' || r == 'geraetewart');
  }
  final rolle = mitgliedschaften[selected];
  if (rolle == 'admin' || rolle == 'geraetewart') return true;

  // Temporäres Gerätewart-Recht (Stufe ③, #100): dieselbe Freischaltung wie
  // eine Schreibrolle, nur mit Ablauf. Der Server prüft es noch einmal in
  // can_publish_abteilung — hier wird nur die Oberfläche freigegeben.
  final temporaer = ref.watch(meineTemporaerenRechteProvider).value;
  final laeuftAb = temporaer?[selected];
  if (laeuftAb != null && laeuftAb.isAfter(DateTime.now())) return true;

  // Feuerwehrkommandant: schreibt in jeder Abteilung seiner Gesamtwehr.
  final kommandiert = ref.watch(meineKommandoGesamtwehrenProvider).value;
  if (kommandiert == null || kommandiert.isEmpty) return false;
  final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
  for (final a in abteilungen) {
    if (a.id == selected) {
      return a.gesamtwehrId != null && kommandiert.contains(a.gesamtwehrId);
    }
  }
  return false;
});

/// Verwalter-Blick (Nutzerverwaltung, Gesamtwehr-Screen, Branding):
/// Feuerwehrkommandant oder Abteilungskommandant irgendeiner Abteilung.
/// In pure local mode true, wie canEdit.
final isAdminProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return true;
  final mitgliedschaften = ref.watch(meineMitgliedschaftenProvider).value;
  if (mitgliedschaften == null) {
    // Alt-Server: Spiegel-Rolle.
    return ref.watch(currentUserRoleProvider).value == 'admin';
  }
  if (mitgliedschaften.values.contains('admin')) return true;
  final kommandiert = ref.watch(meineKommandoGesamtwehrenProvider).value;
  return kommandiert != null && kommandiert.isNotEmpty;
});

/// M7 Etappe 3: true, solange das vom Admin gesetzte Initialpasswort noch
/// nicht geändert wurde. Die Settings zeigen dann einen nicht umgehbaren
/// Pflichtwechsel-Dialog; nach dem Wechsel wird das Flag per RPC gelöscht
/// und dieser Provider invalidiert.
final mustChangePasswordProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return false;
  final row = await client
      .from('profiles')
      .select('must_change_password')
      .eq('id', session.user.id)
      .maybeSingle();
  return (row?['must_change_password'] as bool?) ?? false;
});

/// Uploads local equipment photos to the central bucket (M2); null while
/// Supabase is not initialised (pure local mode).
final imageSyncServiceProvider = Provider<ImageSyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : ImageSyncService(client);
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  // Abteilungswahl (Issue #57 Phase 2): Datenbank UND Sync hängen an der
  // Auswahl — der Provider baut sich bei einem Wechsel komplett neu auf.
  final service = SyncService(
    ref.watch(appDatabaseProvider),
    client,
    abteilungOverride: ref.watch(selectedAbteilungIdProvider),
  );
  service.startDirtyTracking();
  ref.onDispose(service.dispose);
  return service;
});

/// Der zeilenweise Sync der Gerätetypen (Nutzerkonzept Stufe ②, Issue #99).
/// Hängt wie [syncServiceProvider] an der gewählten Abteilung — über sie
/// findet er die Gesamtwehr, deren Typ-Bestand gilt.
final equipmentTypeSyncProvider = Provider<EquipmentTypeSync?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return EquipmentTypeSync(
    ref.watch(appDatabaseProvider),
    client,
    abteilungOverride: ref.watch(selectedAbteilungIdProvider),
  );
});

/// Live-Erreichbarkeitscheck des Sync-Servers (GET /auth/v1/health).
/// Zeigt VOR dem Login, ob der Server überhaupt antwortet — deckt die
/// häufigen Fälle auf (kein Internet, Server down), die sich
/// sonst erst als fehlgeschlagener Login äußern. Erneut prüfen per
/// ref.invalidate(serverHealthProvider).
final serverHealthProvider = FutureProvider.autoDispose<bool>((ref) async {
  final base = supabaseStorageBaseUrl;
  if (base == null) return false;
  try {
    final resp = await http
        .get(Uri.parse('$base/auth/v1/health'),
            headers: supabaseStorageHeaders?.call())
        .timeout(const Duration(seconds: 4));
    return resp.statusCode == 200;
  } on TimeoutException {
    return false;
  } catch (_) {
    // Jeder Netz-/DNS-Fehler bedeutet schlicht: Server nicht erreichbar.
    return false;
  }
});

/// Local sync bookkeeping (last pulled version, dirty flag) as a stream.
final syncMetaStreamProvider = StreamProvider<SyncMetaData?>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return Stream.value(null);
  return service.watchMeta();
});
