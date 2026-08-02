/// abteilung_picker.dart – Abteilungs-Kachel in den Einstellungen
/// (Issue #57 Phase 2).
///
/// Seit Issue #96 steht der Wähler zusätzlich in der AppBar jeder Seite; die
/// Kachel bleibt, weil sie mehr Platz für den Rechte-Hinweis hat und dort
/// gesucht wird, wo alles andere zum Konto steht. Auswahl-Sheet und Wechsel
/// liegen gemeinsam in `core/widgets/abteilung_switcher.dart` — zwei Wege in
/// dieselbe Entscheidung, aber nur eine Umsetzung.
///
/// Sichtbar nur, wenn der Server Abteilungen kennt und der Nutzer angemeldet
/// ist; im Lokalmodus und auf Legacy-Servern liefert der Provider eine leere
/// Liste und die Kachel verschwindet von selbst.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';

class AbteilungTile extends ConsumerWidget {
  const AbteilungTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    if (abteilungen.isEmpty) return const SizedBox.shrink();

    final own = ref.watch(myAbteilungIdProvider).value;
    final selectedId = ref.watch(selectedAbteilungIdProvider) ?? own;
    final selected = abteilungen.where((a) => a.id == selectedId).firstOrNull;
    final istHeimat = selectedId != null && selectedId == own;

    final rechte = selected == null
        ? null
        : abteilungsRechteText(
            selected,
            istHeimat: istHeimat,
            mitgliedschaften: ref.watch(meineMitgliedschaftenProvider).value,
            kommandierteGesamtwehren:
                ref.watch(meineKommandoGesamtwehrenProvider).value,
          );
    final wechselbar = abteilungen.length > 1;

    return ListTile(
      leading: Icon(istHeimat ? Icons.home_work : Icons.visibility),
      title: Text(selected == null ? 'Abteilung' : abteilungsTitel(selected)),
      // Kein „zum Wechseln tippen" mehr: Das Wechsel-Symbol rechts sagt es
      // kürzer, und der Platz gehört jetzt der Rechte-Aussage.
      subtitle: Text(rechte ?? 'Abteilung wählen'),
      trailing: wechselbar ? const Icon(Icons.swap_horiz) : null,
      onTap: wechselbar ? () => showAbteilungPicker(context, ref) : null,
    );
  }
}
