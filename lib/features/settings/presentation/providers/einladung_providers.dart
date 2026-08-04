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
import 'package:fwapp/features/settings/domain/zustellung.dart';
import 'package:fwapp/features/settings/presentation/providers/user_admin_providers.dart';

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

/// Was der Server über die Zustellung der offenen Einladungen weiß
/// (Issue #121).
class Zustellstand {
  /// `false`, wenn der Server gar nicht fragen konnte — kein Brevo-Schlüssel
  /// hinterlegt, Brevo nicht erreichbar, Schlüssel abgelehnt. Dann steht in
  /// der Liste „nicht prüfbar" und ausdrücklich nicht „alles in Ordnung".
  final bool verfuegbar;
  final String? grund;

  /// Wie viele Einladungen der Server nicht mehr abgefragt hat (Obergrenze
  /// je Aufruf). Wird angezeigt statt verschwiegen.
  final int gekuerzt;

  final Map<String, Zustellung> proEinladung;

  const Zustellstand({
    required this.verfuegbar,
    required this.gekuerzt,
    required this.proEinladung,
    this.grund,
  });

  static const leer =
      Zustellstand(verfuegbar: false, gekuerzt: 0, proEinladung: {});

  Zustellung fuer(String einladungId) =>
      proEinladung[einladungId] ?? Zustellung.unbekannt;
}

/// Fragt die Edge Function nach den Brevo-Ereignissen der offenen
/// Einladungen und ordnet sie ein.
///
/// Getrennt von [offeneEinladungenProvider], weil die Liste aus der Tabelle
/// sofort da ist und der Umweg über Brevo Sekunden dauern kann: Die
/// Einladungen sollen nicht auf die Zustellung warten. Solange nichts
/// geladen ist, steht schlicht keine Zustellzeile da.
final einladungZustellungProvider =
    FutureProvider.autoDispose<Zustellstand>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  // Hängt an der Liste: Nach jedem Einladen, Zurückziehen oder erneuten
  // Senden ist der alte Zustellstand hinfällig.
  final einladungen = ref.watch(offeneEinladungenProvider).value ?? const [];
  if (client == null || session == null || einladungen.isEmpty) {
    return Zustellstand.leer;
  }
  try {
    final daten =
        await invokeAdminUsers(client, {'action': 'invite_status'});
    final roh = (daten['zustellungen'] as Map?) ?? const {};
    return Zustellstand(
      verfuegbar: daten['verfuegbar'] == true,
      grund: daten['grund'] as String?,
      gekuerzt: (daten['gekuerzt'] as num?)?.toInt() ?? 0,
      proEinladung: {
        for (final eintrag in roh.entries)
          eintrag.key as String: zustellungAus([
            for (final e in (eintrag.value as List? ?? const []))
              if (DateTime.tryParse(
                      (e as Map)['zeit'] as String? ?? '') !=
                  null)
                Zustellereignis(
                  art: e['art'] as String? ?? '',
                  zeit: DateTime.parse(e['zeit'] as String),
                  grund: e['grund'] as String?,
                ),
          ]),
      },
    );
  } catch (e) {
    // Ein alter Server kennt die Aktion nicht — genau derselbe Umgang wie
    // bei der Liste selbst: kein Fehlerbildschirm, nur keine Auskunft.
    appLog.i('Zustellung nicht abfragbar (Server ohne Issue #121?)', error: e);
    return Zustellstand.leer;
  }
});
