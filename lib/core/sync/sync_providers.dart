/// sync_providers.dart – Riverpod providers for Supabase client, auth state,
/// role (admin/member), and the SyncService. Written as manual providers
/// (riverpod_generator cannot emit code for supabase_flutter's types).
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/sync_service.dart';
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

/// Gate for all editing UI.
/// - Not connected to a department (pure local/demo mode): full control.
/// - Connected: only the admin role may edit; members (and signed-out
///   users on a connected install) are read-only.
final isAdminProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return true;
  return ref.watch(currentUserRoleProvider).value == 'admin';
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final service = SyncService(ref.watch(appDatabaseProvider), client);
  service.startDirtyTracking();
  ref.onDispose(service.dispose);
  return service;
});

/// Local sync bookkeeping (last pulled version, dirty flag) as a stream.
final syncMetaStreamProvider = StreamProvider<SyncMetaData?>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return Stream.value(null);
  return service.watchMeta();
});
