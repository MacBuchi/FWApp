/// betrieb_eintrag.dart – Der Weg in die Konsole (Issue #101): ein Eintrag
/// in den Einstellungen, den nur der KreisDatenMeister sieht.
///
/// NUTZERKONZEPT §6 will die Konsole „ohne Navigations-Link" — für alle
/// anderen. Der Betreiber selbst braucht einen Weg hinein: Die Android-App
/// hat keine Adresszeile, in die er `/betrieb` tippen könnte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/betrieb/presentation/providers/betrieb_providers.dart';

class BetriebEintrag extends ConsumerWidget {
  const BetriebEintrag({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(istBetreiberProvider).value != true) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(Icons.hub_outlined),
      title: const Text('KreisDatenMeister'),
      subtitle: const Text('Alle Wehren dieser Installation verwalten'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/betrieb'),
    );
  }
}
