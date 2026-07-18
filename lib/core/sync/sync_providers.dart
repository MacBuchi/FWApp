/// sync_providers.dart – Riverpod providers for Supabase client, auth state,
/// role (admin/member), and the SyncService. Written as manual providers
/// (riverpod_generator cannot emit code for supabase_flutter's types).
library;
import 'dart:async' show TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/image_sync_service.dart';
import 'package:fwapp/core/sync/sync_service.dart';
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

/// Role of the signed-in user ('admin' | 'member'), null when signed out.
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

/// Gate for all editing UI (M7: Rollen admin | geraetewart | member).
/// - Not connected to a department (pure local/demo mode): full control.
/// - Connected: admin und geraetewart dürfen bearbeiten/veröffentlichen;
///   members (and signed-out users on a connected install) are read-only.
final canEditProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return true;
  final role = ref.watch(currentUserRoleProvider).value;
  return role == 'admin' || role == 'geraetewart';
});

/// Strictly the admin role (Nutzerverwaltung/Reset, M7 Etappe 3).
/// In pure local mode true, wie canEdit.
final isAdminProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return true;
  return ref.watch(currentUserRoleProvider).value == 'admin';
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
  final service = SyncService(ref.watch(appDatabaseProvider), client);
  service.startDirtyTracking();
  ref.onDispose(service.dispose);
  return service;
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
    return false;
  }
});

/// Local sync bookkeeping (last pulled version, dirty flag) as a stream.
final syncMetaStreamProvider = StreamProvider<SyncMetaData?>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return Stream.value(null);
  return service.watchMeta();
});
