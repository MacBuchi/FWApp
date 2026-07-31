/// changelog_screen.dart – „Was ist neu?": Versionsübersicht aus der
/// mitgelieferten CHANGELOG.md (Issue #51).
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fwapp/core/changelog/changelog.dart';

class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(changelogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Was ist neu?')),
      body: releasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (releases) {
          if (releases.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Die Änderungsliste ist derzeit nicht verfügbar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              // Die installierte Version bekommt eine Markierung, damit man
              // sofort sieht, was man selbst hat und was schon darüber liegt.
              final installed = snap.data?.version;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: releases.length,
                itemBuilder: (context, i) => _ReleaseTile(
                  release: releases[i],
                  isInstalled: releases[i].version == installed,
                  initiallyExpanded: i == 0,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  final ChangelogRelease release;
  final bool isInstalled;
  final bool initiallyExpanded;

  const _ReleaseTile({
    required this.release,
    required this.isInstalled,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Row(
        children: [
          Text('Version ${release.version}',
              style: theme.textTheme.titleMedium),
          if (isInstalled) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text('installiert'),
              labelStyle: theme.textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
      subtitle: release.date != null ? Text(_formatDate(release.date!)) : null,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in release.sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              section.title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final entry in section.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(entry)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// `2026-07-31` → `31.07.2026`. Bewusst ohne `intl`-Locale-Initialisierung:
  /// Die Datumsform in der CHANGELOG.md ist fest, und die App ist einsprachig.
  static String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }
}
