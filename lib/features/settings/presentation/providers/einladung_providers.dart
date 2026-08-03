/// einladung_providers.dart – Offene Mail-Einladungen (Nutzerkonzept Stufe 3,
/// Issue #100).
///
/// Gelesen wird DIREKT aus `einladungen`: Die Lese-Policy der Tabelle gibt
/// genau die Zeilen heraus, die der Angemeldete auch verwalten darf
/// (`darf_mitglieder_verwalten`) — ein Umweg über die Edge Function würde
/// dieselbe Regel ein zweites Mal formulieren. Geschrieben wird dagegen
/// ausschließlich über die Function: Nur sie darf mit dem Service-Key den
/// Mailversand über GoTrue anstoßen.
///
/// Manuelle Provider wie der Rest der Supabase-Anbindung (Supabase-Typen
/// vertragen keinen riverpod-Codegen, siehe sync_providers.dart).
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';

/// Eine noch offene Einladung.
class Einladung {
  final String id;
  final String email;

  /// Der Name, unter dem die Person in der Wehr bekannt ist. Er landet beim
  /// Annehmen im Profil — sonst hieße jemand fortan „vorname.nachname".
  final String? anzeigename;
  final String abteilungId;
  final String role;
  final bool alsKommandant;
  final DateTime? createdAt;

  const Einladung({
    required this.id,
    required this.email,
    required this.anzeigename,
    required this.abteilungId,
    required this.role,
    required this.alsKommandant,
    required this.createdAt,
  });

  factory Einladung.fromJson(Map<String, dynamic> json) => Einladung(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        anzeigename: json['anzeigename'] as String?,
        abteilungId: json['abteilung_id'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        alsKommandant: json['als_kommandant'] as bool? ?? false,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );
}

/// Alle offenen Einladungen im Verwaltungsbereich des Angemeldeten.
///
/// Leere Liste statt Fehler, wenn der Server die Tabelle nicht kennt: Genau
/// so verhält sich ein Server, der die Stufe-3-Migration noch nicht hat —
/// und die Nutzerverwaltung soll dort weiter benutzbar bleiben.
final offeneEinladungenProvider =
    FutureProvider.autoDispose<List<Einladung>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return const [];
  try {
    final rows = await client
        .from('einladungen')
        .select('id, email, anzeigename, abteilung_id, role, als_kommandant, '
            'created_at')
        .isFilter('angenommen_am', null)
        .isFilter('zurueckgezogen_am', null)
        .order('created_at');
    return [
      for (final r in rows)
        Einladung.fromJson((r as Map).cast<String, dynamic>()),
    ];
  } catch (e) {
    appLog.i('Einladungen nicht ladbar (Server ohne Stufe 3?)', error: e);
    return const [];
  }
});
