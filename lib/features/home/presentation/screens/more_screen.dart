/// more_screen.dart – "Mehr" tab: lookup, settings, and (admins only) the
/// Verwaltung section. Normal members never see editing entry points.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/export/csv_datei.dart';
import 'package:fwapp/core/sharing/teilen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/inventory/data/bestand_export.dart';
import 'package:fwapp/features/inventory/presentation/providers/bestand_export_providers.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/home/presentation/widgets/home_banners.dart';

/// Baut den Bestands-Export und gibt ihn ans Teilen-Blatt weiter (#176).
///
/// Kein eigener Bildschirm: Es gibt nichts einzustellen. Ein Assistent für
/// eine Datei, die immer gleich aussieht, wäre ein Klick mehr ohne eine
/// Entscheidung dahinter.
Future<void> _bestandTeilen(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final jetzt = DateTime.now();
  try {
    final csv = await bestandAlsCsv(ref.read(appDatabaseProvider));
    if (!context.mounted) return;
    await teile(
      context,
      csv,
      dateiname: bestandDateiname(zeitpunkt: jetzt),
      betreff: 'Gerätebestand ${csvDatum(jetzt)}',
      sacheImRueckfall: 'der Bestand',
    );
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')));
  }
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canEditProvider);
    // Feedback landet in Supabase — braucht Server + Login.
    final showFeedback = ref.watch(supabaseReadyProvider) &&
        ref.watch(sessionStreamProvider).value != null;
    // Nutzerverwaltung: nur echter Admin UND verbundener Server (im reinen
    // Lokalmodus gibt es keine zentralen Konten).
    final showUserManagement = ref.watch(isAdminProvider) &&
        ref.watch(supabaseReadyProvider);
    // Abteilung & Gesamtwehr (#57 Phase 3): auch der Gerätewart kommt hier
    // rein — er darf einen Anschluss beantragen, nur nicht entscheiden.
    final showGesamtwehr = canEdit && ref.watch(supabaseReadyProvider);
    final syncMeta = ref.watch(syncMetaStreamProvider).value;
    final dirty = syncMeta?.localDirty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mehr'),
        actions: const [AbteilungAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section('Nachschlagen'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('Gerätekatalog'),
                  subtitle: const Text('Alle Geräte durchsuchen und filtern'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/equipment'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.image_search),
                  title: const Text('Bildbibliothek'),
                  subtitle:
                      const Text('Symbolbilder aller Normgeräte durchsuchen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/image-library'),
                ),
              ],
            ),
          ),
          _Section('App'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Einstellungen'),
                  subtitle: const Text('Design, Synchronisation, Konto'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
                if (showFeedback) ...[
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.lightbulb_outline),
                    title: const Text('Feedback senden'),
                    subtitle:
                        const Text('Wunsch oder Fehler an den Entwickler'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showFeedbackDialog(context, ref),
                  ),
                ],
              ],
            ),
          ),
          if (canEdit) ...[
            _Section('Verwaltung (Gerätewart)'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.fact_check),
                    title: const Text('Prüftermine'),
                    subtitle:
                        const Text('Fällige Prüfungen und Ablaufdaten'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/inspections'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Beladeliste importieren'),
                    subtitle: const Text('Excel/CSV mit Zuordnungs-Assistent'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/import'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: const Text('Inventur'),
                    subtitle: const Text('Fahrzeug fach für fach prüfen'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/inventory'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  // Neben dem Import, weil es sein Gegenstück ist (#176).
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Bestand exportieren'),
                    subtitle: const Text(
                        'CSV zum Archivieren oder für andere Programme'),
                    onTap: () => _bestandTeilen(context, ref),
                  ),
                  if (showUserManagement) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.manage_accounts),
                      title: const Text('Nutzerverwaltung'),
                      subtitle: const Text(
                          'Einladen, Konten anlegen, Passwörter zurücksetzen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/user-management'),
                    ),
                  ],
                  if (showGesamtwehr) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.account_tree),
                      title: const Text('Abteilung & Gesamtwehr'),
                      subtitle: const Text(
                          'Abteilungen anlegen und verbinden (#57)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/gesamtwehr'),
                    ),
                  ],
                  if (dirty) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.cloud_upload,
                          color: Colors.orange.shade800),
                      title: const Text('Unveröffentlichte Änderungen'),
                      subtitle: const Text(
                          'In den Einstellungen veröffentlichen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4)),
      );
}
