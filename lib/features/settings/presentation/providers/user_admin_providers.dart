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

  /// Heimat-Abteilung (Issue #57). `null` auf Servern ohne Mandanten-Schema
  /// oder wenn die Abteilung gelöscht wurde (Profil überlebt das bewusst).
  final String? abteilungId;

  /// Rolle je Abteilung (Nutzerkonzept Stufe 1). Auf Alt-Servern aus
  /// role/abteilungId synthetisiert, damit die UI nur eine Form kennt.
  final Map<String, String> memberships;

  /// Gesamtwehren, deren Feuerwehrkommandant dieses Konto ist.
  final List<String> kommandantGesamtwehren;

  /// Ob der Server Mitgliedschaften kennt — entscheidet, welche
  /// Verwaltungs-Dialoge die UI anbietet.
  final bool hatMitgliedschaften;

  const ManagedUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    required this.banned,
    required this.lastSignInAt,
    this.abteilungId,
    this.memberships = const {},
    this.kommandantGesamtwehren = const [],
    this.hatMitgliedschaften = false,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'member';
    final abteilungId = json['abteilung_id'] as String?;
    final rawMemberships = json['memberships'] as List?;
    return ManagedUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      banned: json['banned'] as bool? ?? false,
      lastSignInAt: json['last_sign_in_at'] == null
          ? null
          : DateTime.tryParse(json['last_sign_in_at'] as String),
      abteilungId: abteilungId,
      memberships: rawMemberships != null
          ? {
              for (final m in rawMemberships)
                (m as Map)['abteilung_id'] as String: m['role'] as String,
            }
          : {if (abteilungId != null) abteilungId: role},
      kommandantGesamtwehren: [
        for (final g in (json['kommandant_gesamtwehren'] as List? ?? const []))
          g as String,
      ],
      hatMitgliedschaften: rawMemberships != null,
    );
  }
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
