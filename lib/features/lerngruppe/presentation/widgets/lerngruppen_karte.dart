/// lerngruppen_karte.dart – Karte auf der Startseite, solange eine
/// Lerngruppe läuft (Issue #136).
///
/// Erst mit der Rangliste, nicht schon mit dem Bildschirm (#231): Vorher
/// stünde hier nur „läuft noch 42 Tage" — eine Karte, die nichts zu tun
/// gibt, lernt man zu übersehen. Jetzt sagt sie, was diese Woche dran ist
/// und wo man steht.
///
/// Ohne Anmeldung, ohne Netz oder ohne laufende Gruppe erscheint sie gar
/// nicht: Die Startseite ist local-first und darf nicht auf den Server
/// warten.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/domain/wertung.dart';
import 'package:fwapp/features/lerngruppe/presentation/providers/lerngruppe_providers.dart';

class LerngruppenKarte extends ConsumerWidget {
  const LerngruppenKarte({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heute = DateTime.now();
    final laufend = [
      for (final g in sortiereLerngruppen(
        ref.watch(meineLerngruppenProvider).value ?? const [],
        heute,
      ))
        if (g.laeuftAm(heute)) g,
    ];
    if (laufend.isEmpty) return const SizedBox.shrink();

    // Die am frühesten endende zuerst (sortiereLerngruppen) — sie braucht
    // die Aufmerksamkeit.
    final gruppe = laufend.first;
    final aufgabe = ref.watch(lerngruppeWochenaufgabeProvider(gruppe.id)).value;
    final wertungen =
        ref.watch(lerngruppenWertungenProvider(gruppe.id)).value ?? const [];
    final mitglieder =
        ref.watch(lerngruppenMitgliederProvider(gruppe.id)).value ?? const [];
    final ichId = ref.watch(sessionStreamProvider).value?.user.id;

    final stand = standText(
      aufgabe: aufgabe,
      mitglieder: [for (final m in mitglieder) m.userId],
      wertungen: wertungen,
      ichId: ichId,
    );
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.diversity_3, color: theme.colorScheme.primary),
          title: Text(gruppe.name),
          subtitle: Text(
            [
              if (aufgabe != null) 'Wochenaufgabe: ${aufgabe.modus.titel}',
              if (stand != null) stand,
              if (laufend.length > 1)
                laufend.length == 2
                    ? '+ 1 weitere Lerngruppe'
                    : '+ ${laufend.length - 1} weitere Lerngruppen',
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/lerngruppen/${gruppe.id}'),
        ),
      ),
    );
  }
}

/// „Platz 2 von 5" oder die Aufforderung, diese Woche mitzuspielen. `null`,
/// solange die Aufgabe (noch) nicht geladen ist.
String? standText({
  required Wochenaufgabe? aufgabe,
  required List<String> mitglieder,
  required List<Wertung> wertungen,
  required String? ichId,
}) {
  if (aufgabe == null || ichId == null || mitglieder.isEmpty) return null;
  final ich =
      wochenRangliste(
        mitglieder,
        wertungen,
        aufgabe.woche,
      ).where((p) => p.userId == ichId).firstOrNull;
  final platz = ich?.platz;
  if (platz == null) return 'Du hast diese Woche noch nicht gespielt.';
  return 'Platz $platz von ${mitglieder.length} · ${ich!.punkte} %';
}
