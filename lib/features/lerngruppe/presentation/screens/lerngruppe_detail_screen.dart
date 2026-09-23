/// lerngruppe_detail_screen.dart – Eine Lerngruppe: Laufzeit, Code zum
/// Weitergeben, wer drin ist, verlassen (Issue #136).
///
/// Liest die Gruppe aus [meineLerngruppenProvider] statt sie als `extra`
/// mitzubekommen: So überlebt die Seite ein Neuladen im Browser, und nach
/// dem Verlassen steht dort ehrlich „nicht mehr dabei" statt einer Gruppe,
/// die es für einen gar nicht mehr gibt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sharing/teilen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/presentation/providers/lerngruppe_providers.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';

class LerngruppeDetailScreen extends ConsumerWidget {
  final String gruppeId;
  const LerngruppeDetailScreen({super.key, required this.gruppeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruppen = ref.watch(meineLerngruppenProvider);
    final gruppe = gruppen.value?.where((g) => g.id == gruppeId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(gruppe?.name ?? 'Lerngruppe'),
        actions: [
          if (gruppe != null)
            IconButton(
              tooltip: 'Gruppe verlassen',
              icon: const Icon(Icons.logout),
              onPressed: () => _verlassen(context, ref, gruppe),
            ),
        ],
      ),
      body:
          gruppen.isLoading && gruppe == null
              ? const Center(child: CircularProgressIndicator())
              : gruppe == null
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'In dieser Lerngruppe bist du nicht (mehr) dabei.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : _Inhalt(gruppe: gruppe),
    );
  }

  Future<void> _verlassen(
    BuildContext context,
    WidgetRef ref,
    Lerngruppe gruppe,
  ) async {
    final ja = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: const Text('Lerngruppe verlassen?'),
            content: Text(
              'Du bist danach nicht mehr in „${gruppe.name}". Zurück geht '
              'es nur mit dem Code, solange die Gruppe noch läuft.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Verlassen'),
              ),
            ],
          ),
    );
    if (ja != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final dienst = ref.read(lerngruppeServiceProvider);
    if (dienst == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kein Server verbunden.')),
      );
      return;
    }
    try {
      await dienst.verlasse(gruppe.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('„${gruppe.name}" verlassen.')),
      );
      context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(lerngruppeFehler(e))));
    }
  }
}

class _Inhalt extends ConsumerWidget {
  final Lerngruppe gruppe;
  const _Inhalt({required this.gruppe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final heute = DateTime.now();
    final laeuft = gruppe.laeuftAm(heute);
    final mitglieder = ref.watch(lerngruppenMitgliederProvider(gruppe.id));
    final ichId = ref.watch(sessionStreamProvider).value?.user.id;

    return RefreshIndicator(
      onRefresh:
          () => ref.refresh(lerngruppenMitgliederProvider(gruppe.id).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(gruppe.laufzeitText(heute), style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          // Der Code nur, solange er noch etwas nützt: Einer beendeten
          // Gruppe tritt der Server nicht mehr bei.
          if (laeuft) _CodeKarte(gruppe: gruppe),
          const SizedBox(height: 24),
          Text('Wer dabei ist', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...mitglieder.when(
            loading:
                () => const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
            error: (e, _) => [Text(lerngruppeFehler(e))],
            data:
                (liste) => [
                  for (final m in liste)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: FwAvatar(
                        konfiguration: AvatarKonfiguration.dekodiert(m.avatar),
                      ),
                      title: Text(
                        m.userId == ichId
                            ? '${m.anzeigeName} (du)'
                            : m.anzeigeName,
                      ),
                    ),
                  if (liste.length == 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Noch bist du allein. Gib den Code weiter!',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
          ),
          const SizedBox(height: 24),
          // Ehrlich sagen, was noch fehlt — sonst sucht man die Rangliste.
          Text(
            'Wochenaufgabe und Rangliste kommen mit einem der nächsten '
            'Updates.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeKarte extends StatelessWidget {
  final Lerngruppe gruppe;
  const _CodeKarte({required this.gruppe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Beitrittscode', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(
              gruppe.codeLesbar,
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.share),
              label: const Text('Code weitergeben'),
              onPressed:
                  () => teile(
                    context,
                    gruppe.einladungsText,
                    sacheImRueckfall: 'die Einladung',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
