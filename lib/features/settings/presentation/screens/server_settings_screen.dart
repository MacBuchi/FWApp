/// server_settings_screen.dart – Der Notausgang aus dem Anmeldezwang.
///
/// Ohne Anmeldung erreichbar (siehe `_publicPaths` in app_router.dart), und
/// das ist der ganze Zweck: Wer eine falsche oder tote Serveradresse
/// eingetragen hat, kommt sonst nirgends mehr hin — anmelden geht nicht, und
/// die Einstellungen lägen hinter der Anmeldung. Genau diese Sackgasse
/// verhindert dieser Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/widgets/sync_config_section.dart';

class ServerSettingsScreen extends ConsumerWidget {
  const ServerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servereinstellungen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Direkt per URL aufgerufen (Web) gibt es nichts zu poppen — dann
          // zurück zur Anmeldung statt in eine Sackgasse ohne Ausweg.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Hier stehen Adresse und Schlüssel des Servers, mit dem sich '
              'die App verbindet.\n\n'
              'Änderungen wirken erst nach einem vollständigen Neustart der '
              'App.\n\n'
              'Ist der Server dauerhaft nicht erreichbar, schalte die '
              'Cloud-Synchronisation ab: Die App startet dann im Lokalmodus '
              'und ist auch ohne Anmeldung nutzbar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          if (ref.watch(supabaseReadyProvider)) const ServerHealthTile(),
          const SyncConfigSection(),
        ],
      ),
    );
  }
}
