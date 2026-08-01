/// abteilung_picker.dart – Anzeige und Wechsel der Abteilung
/// (Issue #57 Phase 2).
///
/// Sichtbar nur, wenn der Server Abteilungen kennt und der Nutzer angemeldet
/// ist; im Lokalmodus und auf Legacy-Servern liefert der Provider eine leere
/// Liste und die Kachel verschwindet von selbst.
///
/// Die eigene Abteilung wird intern als `null` geführt (angestammte
/// Datenbank-Datei, siehe abteilung_providers.dart) — der Picker übersetzt
/// das an genau einer Stelle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';

class AbteilungTile extends ConsumerWidget {
  const AbteilungTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    if (abteilungen.isEmpty) return const SizedBox.shrink();

    final own = ref.watch(myAbteilungIdProvider).value;
    final selectedId = ref.watch(selectedAbteilungIdProvider) ?? own;
    final selected = abteilungen
        .where((a) => a.id == selectedId)
        .firstOrNull;
    final isSister = selectedId != null && selectedId != own;

    return ListTile(
      leading: Icon(isSister ? Icons.visibility : Icons.home_work),
      title: Text(selected == null
          ? 'Abteilung'
          : selected.gesamtwehrName == null
              ? selected.name
              : '${selected.name} · ${selected.gesamtwehrName}'),
      subtitle: Text(isSister
          ? 'Schwester-Abteilung — nur lesen'
          : abteilungen.length > 1
              ? 'Deine Abteilung — zum Wechseln tippen'
              : 'Deine Abteilung'),
      trailing:
          abteilungen.length > 1 ? const Icon(Icons.swap_horiz) : null,
      onTap: abteilungen.length > 1
          ? () => _showPicker(context, ref, own)
          : null,
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    String? own,
  ) async {
    final target = await showModalBottomSheet<AbteilungInfo>(
      context: context,
      builder: (context) => _AbteilungSheet(own: own),
    );
    if (target == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Eigene Abteilung = null: Sie behält die angestammte Datenbank-Datei.
    await ref
        .read(abteilungSwitcherProvider)
        .switchTo(target.id == own ? null : target.id);
    messenger.showSnackBar(SnackBar(
      content: Text(target.id == own
          ? 'Zurück in deiner Abteilung.'
          : '${target.name}: nur lesen. Der Bestand wird geladen …'),
    ));
  }
}

class _AbteilungSheet extends ConsumerWidget {
  const _AbteilungSheet({required this.own});

  final String? own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    final selectedId = ref.watch(selectedAbteilungIdProvider) ?? own;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('Abteilung wählen',
                style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'In Schwester-Abteilungen kannst du alles ansehen und damit '
              'lernen — bearbeiten kann dort nur deren Gerätewart.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final a in abteilungen)
            ListTile(
              leading: Icon(
                a.id == own ? Icons.home_work : Icons.visibility,
                color: a.id == selectedId ? theme.colorScheme.primary : null,
              ),
              title: Text(a.gesamtwehrName == null
                  ? a.name
                  : '${a.name} · ${a.gesamtwehrName}'),
              subtitle: Text(a.id == own
                  ? 'Deine Abteilung'
                  : 'Nur lesen'),
              trailing: a.id == selectedId
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, a),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
