/// user_admin_providers.dart – Admin-Nutzerverwaltung (M7 Etappe 3) über die
/// Edge Function `admin-users`. Manuelle Provider (Supabase-Typen).
///
/// Der Service-Role-Key bleibt auf dem Server; die App ruft die Function mit
/// dem Admin-JWT auf, die Function prüft die Rolle serverseitig.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, SupabaseClient;

/// Ein zentral verwaltetes Konto, wie es die Edge Function liefert.
class ManagedUser {
  final String id;
  final String username;
  final String email;
  final String role;
  final bool mustChangePassword;
  final bool banned;
  final DateTime? lastSignInAt;

  const ManagedUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    required this.banned,
    required this.lastSignInAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        mustChangePassword: json['must_change_password'] as bool? ?? false,
        banned: json['banned'] as bool? ?? false,
        lastSignInAt: json['last_sign_in_at'] == null
            ? null
            : DateTime.tryParse(json['last_sign_in_at'] as String),
      );
}

/// Führt eine Aktion der admin-users-Function aus und liefert deren
/// JSON-Antwort. Wirft mit verständlicher Meldung bei Fehlern.
/// (Nimmt den Client statt eines Ref, damit Provider UND Widgets sie
/// nutzen können — WidgetRef ist in Riverpod 3 kein Ref.)
Future<Map<String, dynamic>> invokeAdminUsers(
    SupabaseClient? client, Map<String, dynamic> body) async {
  if (client == null) {
    throw StateError('Kein Server verbunden (Sync nicht initialisiert).');
  }
  try {
    final resp = await client.functions.invoke('admin-users', body: body);
    return (resp.data as Map).cast<String, dynamic>();
  } on FunctionException catch (e) {
    final detail = e.details;
    final msg = detail is Map && detail['error'] != null
        ? detail['error'].toString()
        : 'HTTP ${e.status}';
    throw Exception(msg);
  }
}

/// Liste aller Konten; neu laden per ref.invalidate.
final managedUsersProvider =
    FutureProvider.autoDispose<List<ManagedUser>>((ref) async {
  final data = await invokeAdminUsers(
      ref.watch(supabaseClientProvider), {'action': 'list'});
  final users = (data['users'] as List? ?? [])
      .map((u) => ManagedUser.fromJson((u as Map).cast<String, dynamic>()))
      .toList();
  users.sort((a, b) => a.username.compareTo(b.username));
  return users;
});
