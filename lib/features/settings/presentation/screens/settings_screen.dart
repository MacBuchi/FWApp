/// settings_screen.dart – App settings: dark mode, Supabase sync, library info.
library;
import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/image_precache.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/mfa_providers.dart';
import 'package:fwapp/core/sync/rollen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/presentation/providers/profil_providers.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:fwapp/features/settings/presentation/widgets/abteilung_picker.dart';
import 'package:fwapp/features/settings/presentation/widgets/palette_picker.dart';
import 'package:fwapp/features/settings/presentation/widgets/sync_config_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: const [AbteilungAction()],
      ),
      body: ListView(
        children: [
          // ─── Darstellung ─────────────────────────────────────
          _SectionHeader('Darstellung'),
          themeModeAsync.when(
            loading: () => const ListTile(title: Text('Lade...')),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (mode) => Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.brightness_6),
                  title: Text('Design'),
                  subtitle:
                      Text('Standard: folgt der Systemeinstellung'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_suggest),
                          label: Text('System')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Hell')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dunkel')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .set(selection.first),
                  ),
                ),
              ],
            ),
          ),
          // Farbthema nur für Admins (Issue #58): Im reinen Lokalbetrieb ist
          // isAdmin true, alleinstehende Nutzer wählen also frei. Auf einer
          // verbundenen Installation gehört das Erscheinungsbild der Wehr und
          // nicht dem einzelnen Gerät.
          if (ref.watch(isAdminProvider))
            const PalettePicker()
          else
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Farbthema'),
              subtitle: Text('Legt die Verwaltung der Wehr fest.'),
              enabled: false,
            ),

          // ─── Supabase Sync ────────────────────────────────────
          _SectionHeader('Cloud-Synchronisation'),
          const SyncConfigSection(),
          if (ref.watch(supabaseReadyProvider)) ...[
            const ServerHealthTile(),
            const _ConnectionSection(),
          ],

          // ─── Bibliothek ───────────────────────────────────────
          _SectionHeader('Gerätebibliothek'),
          const _LibraryInfoTile(),

          // ─── App-Info ─────────────────────────────────────────
          _SectionHeader('App-Information'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: Text(info != null
                        ? '${info.version} (Build ${info.buildNumber})'
                        : '...'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Was ist neu?'),
                    subtitle: const Text('Änderungen der letzten Versionen'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/changelog'),
                  ),
                  // MIT, BSD und Apache verlangen, dass ihr Lizenztext dem
                  // ausgelieferten Produkt beiliegt — die LICENSE im Repo
                  // reicht dafür nicht. showLicensePage sammelt die Texte
                  // über LicenseRegistry aus allen Paketen selbst ein.
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Open-Source-Lizenzen'),
                    subtitle: const Text(
                        'Verwendete Bibliotheken und ihre Lizenzen'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'FWApp',
                      applicationVersion: info != null
                          ? '${info.version} (Build ${info.buildNumber})'
                          : null,
                      applicationLegalese: '© 2026 Marcus Bucher · MIT-Lizenz',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Version and item count of the bundled equipment library, read from
/// assets/equipment_library/metadata.json.
class _LibraryInfoTile extends StatelessWidget {
  const _LibraryInfoTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context)
          .loadString('assets/equipment_library/metadata.json'),
      builder: (context, snapshot) {
        String subtitle = '…';
        if (snapshot.hasError) {
          subtitle = 'Keine Bibliothek gebündelt';
        } else if (snapshot.hasData) {
          try {
            final meta = jsonDecode(snapshot.data!) as Map<String, dynamic>;
            final vehicles = (meta['vehicles'] as List?)?.join(', ') ?? '?';
            subtitle = 'v${meta['version'] ?? '?'} – '
                '${meta['equipment_count'] ?? '?'} Geräte ($vehicles), '
                'Stand ${meta['last_updated'] ?? '?'}';
          } catch (_) {
            subtitle = 'metadata.json nicht lesbar';
          }
        }
        return ListTile(
          leading: const Icon(Icons.library_books),
          title: const Text('Gebündelte Bibliothek'),
          subtitle: Text(subtitle),
        );
      },
    );
  }
}


/// Login, role, pull and publish actions — shown only when Supabase was
/// initialised at app start.
class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStreamProvider).value;
    final role = ref.watch(currentUserRoleProvider).value;
    final canEdit = ref.watch(canEditProvider);
    final syncMeta = ref.watch(syncMetaStreamProvider).value;

    if (session == null) {
      // Nur noch ein Übergangsbild: Nach dem Abmelden schiebt der Guard im
      // nächsten Frame auf /login. Angemeldet wird dort, nicht mehr hier.
      return const ListTile(
        leading: Icon(Icons.logout),
        title: Text('Abgemeldet …'),
      );
    }

    // Nutzerkonzept Stufe 1: angezeigt wird die Rolle in der GERADE
    // gewählten Abteilung (Feuerwehrkommandant überstimmt); auf
    // Alt-Servern bleibt die Spiegel-Rolle.
    final mitgliedschaften = ref.watch(meineMitgliedschaftenProvider).value;
    final kommandiert =
        ref.watch(meineKommandoGesamtwehrenProvider).value ?? const <String>{};
    final selected = ref.watch(selectedAbteilungIdProvider) ??
        ref.watch(myAbteilungIdProvider).value;
    final rolle =
        mitgliedschaften == null ? role : mitgliedschaften[selected];
    final String roleLabel;
    if (rolle == null && kommandiert.isEmpty) {
      roleLabel = role == null && mitgliedschaften == null
          ? 'Rolle wird geladen...'
          : 'Hier nur Lesezugriff (keine Mitgliedschaft in dieser Abteilung)';
    } else {
      final anzeige = rolleAnzeigename(
        rolle,
        kommandant: kommandiert.isNotEmpty,
        echteMail: hatEchteMail(session.user.email ?? ''),
      );
      roleLabel = canEdit
          ? 'Rolle: $anzeige – darf hier bearbeiten und veröffentlichen'
          : 'Rolle: $anzeige – hier nur Lesezugriff';
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(canEdit ? Icons.admin_panel_settings : Icons.person),
          title: Text(session.user.email ?? 'Angemeldet'),
          subtitle: Text(roleLabel),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider)?.auth.signOut();
            },
            child: const Text('Abmelden'),
          ),
        ),
        // Anzeigename und Avatar gehören dem Konto, nicht der Verwaltung
        // (Issue #100) — deshalb eine eigene Kachel direkt unter dem Konto
        // und nicht in der Nutzerverwaltung.
        const _ProfilTile(),
        // Abteilungswahl (Issue #57 Phase 2) — erscheint nur, wenn der
        // Server Abteilungen kennt.
        const AbteilungTile(),
        // Zwei-Faktor-Anmeldung: freiwillig, für Admins empfohlen
        // (Entscheidung 2026-08-01 — keine Pflicht).
        ListTile(
          leading: Icon(
            ref.watch(hatZweitenFaktorProvider)
                ? Icons.verified_user
                : Icons.shield_outlined,
            color: ref.watch(hatZweitenFaktorProvider) ? Colors.green : null,
          ),
          title: const Text('Zwei-Faktor-Anmeldung'),
          subtitle: Text(ref.watch(hatZweitenFaktorProvider)
              ? 'Aktiv — beim Anmelden wird ein Code abgefragt'
              : 'Zusätzlicher Schutz für dein Konto (für Admins empfohlen)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/zwei-faktor'),
        ),
        // Der Pflichtwechsel des Initialpassworts hat hier keine Kachel mehr:
        // Er ist seit dem Anmeldezwang eine eigene Route, auf die der Guard
        // zwingt — eine übersehbare Kachel wäre die schwächere Durchsetzung.
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Jetzt aktualisieren'),
          subtitle: Text(syncMeta == null || syncMeta.lastPulledAt == null
              ? 'Noch nie synchronisiert'
              : 'Stand: Version ${syncMeta.lastPulledVersion} vom '
                  '${_fmt(syncMeta.lastPulledAt!)}'),
          onTap: () => _pull(context, ref),
        ),
        if (canEdit)
          ListTile(
            leading: Icon(Icons.cloud_upload,
                color: (syncMeta?.localDirty ?? false) ? Colors.orange : null),
            title: const Text('Veröffentlichen'),
            subtitle: Text((syncMeta?.localDirty ?? false)
                ? 'Unveröffentlichte Änderungen vorhanden'
                : 'Lokalen Datenbestand als neue Version veröffentlichen'),
            onTap: () => _publish(context, ref),
          ),
        const _ImageCacheTile(),
      ],
    );
  }

  Future<void> _pull(BuildContext context, WidgetRef ref) async {
    try {
      final version =
          await ref.read(syncServiceProvider)?.pullIfNewer(force: true);
      // Die Gerätetypen der Gesamtwehr kommen auf ihrem eigenen Weg mit
      // (Stufe ②) — „Jetzt aktualisieren" soll alles holen, nicht nur den
      // Bestand der Abteilung.
      await ref.read(equipmentTypeSyncProvider)?.sync();
      unawaited(ref.read(imagePrecacheProvider.notifier).run());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(version == null
                ? 'Bereits aktuell.'
                : 'Datenbestand Version $version geladen.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')));
      }
    }
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Veröffentlichen?'),
        content: const Text(
            'Der lokale Datenbestand ersetzt die zentrale Version für alle '
            'Mitglieder der Abteilung.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Veröffentlichen')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final version = await ref.read(syncServiceProvider)?.publish();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Version $version veröffentlicht.')));
      }
    } on OutdatedClientException {
      // Nur das Veröffentlichen ist gesperrt — die App bleibt lokal nutzbar
      // (Issue #35). Deshalb ein Hinweis, keine Blockade.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'Diese App-Version ist zu alt zum Veröffentlichen. Bitte zuerst '
            'die App aktualisieren — deine lokalen Daten bleiben erhalten '
            'und du kannst weiterarbeiten.',
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().contains('version conflict')
            ? 'Konflikt: Jemand hat zwischenzeitlich veröffentlicht. '
                'Bitte erst „Jetzt aktualisieren“, dann erneut veröffentlichen.'
            : 'Veröffentlichen fehlgeschlagen: $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Erzwungener Passwortwechsel nach dem ersten Login mit Initialpasswort
/// (M7 Etappe 3). Nicht wegklickbar — die einzigen Auswege sind ein neues
/// Passwort oder Abmelden. Löscht danach das must_change_password-Flag
/// per RPC und invalidiert den Provider.

/// Offline availability of the central photos: shows precache progress and
/// lets the user re-run the download (e.g. after a failed first attempt).
/// „Mein Profil": Anzeigename und Avatar (Issue #100).
///
/// Zeigt den Kopf schon in der Kachel — er ist die Antwort auf die Frage,
/// die hinter dem Tippen steht („wie sehe ich aus?"), und ein Standardkopf
/// steht auch dann da, wenn noch nie jemand etwas gewählt hat.
class _ProfilTile extends ConsumerWidget {
  const _ProfilTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(meinProfilProvider).value;
    final name = profil?.name;
    return ListTile(
      leading: FwAvatar(
        konfiguration: profil?.avatar ?? const AvatarKonfiguration(),
        groesse: 40,
      ),
      title: const Text('Mein Profil'),
      subtitle: Text(name == null
          ? 'Anzeigename und Avatar wählen'
          : '$name — Anzeigename und Avatar'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/profil'),
    );
  }
}

class _ImageCacheTile extends ConsumerWidget {
  const _ImageCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(imagePrecacheProvider);

    final String subtitle;
    if (cache.running) {
      subtitle = 'Lade ${cache.done + cache.failed}/${cache.total}…';
    } else if (!cache.hasRun) {
      subtitle = 'Fotos für die Offline-Nutzung herunterladen';
    } else if (cache.failed > 0) {
      subtitle = '${cache.done}/${cache.total} geladen, '
          '${cache.failed} fehlgeschlagen – antippen zum Wiederholen';
    } else {
      subtitle = 'Alle ${cache.done} Fotos offline verfügbar';
    }

    return ListTile(
      leading: cache.running
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.photo_library,
              color: cache.hasRun && cache.failed > 0 ? Colors.orange : null),
      title: const Text('Gerätefotos offline'),
      subtitle: Text(subtitle),
      onTap: cache.running
          ? null
          : () => ref.read(imagePrecacheProvider.notifier).run(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      );
}

