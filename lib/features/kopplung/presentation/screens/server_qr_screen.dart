/// server_qr_screen.dart – „Weiteres Gerät verbinden": der Einrichtungs-QR
/// dieses Servers (Issue #238).
///
/// Jedes angemeldete Mitglied kann ihn zeigen, nicht nur der Betreiber. Das
/// ist Absicht: Der Code enthält nur, was ohnehin in jeder App steckt
/// (Adresse und Anon-Key, den Zugriff schützt RLS), und ein neues Mitglied
/// steht meist neben einem alten, nicht neben dem KreisDatenMeister. Der
/// Code verbindet nur mit dem Server — ein Konto braucht es danach trotzdem.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:fwapp/features/kopplung/presentation/providers/kopplung_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Der Code für den eingetragenen Server; `null`, solange die Einstellungen
/// laden oder kein Server eingetragen ist.
final eigeneKopplungProvider = FutureProvider.autoDispose<ServerKopplung?>((
  ref,
) async {
  final s = await ref.watch(syncSettingsProvider.future);
  final url = normalisiereServerUrl(s.supabaseUrl);
  if (url == null || s.supabaseKey.isEmpty) return null;
  final name = await ref.watch(kopplungsDiensteProvider).gespeicherterName();
  return ServerKopplung(name: name, url: url, anonKey: s.supabaseKey);
});

class ServerQrScreen extends ConsumerWidget {
  const ServerQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kopplung = ref.watch(eigeneKopplungProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Weiteres Gerät verbinden')),
      body: kopplung.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data:
            (k) =>
                k == null
                    ? const Center(
                      child: Text('Es ist kein Server eingetragen.'),
                    )
                    : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Auf dem neuen Gerät: FWApp installieren, auf der '
                          'Anmeldeseite „Mit anderem Server verbinden" → '
                          '„QR-Code scannen", dann diesen Code scannen.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            // Weißer Grund auch im Dunkelmodus: Scanner lesen
                            // dunkle Module auf hellem Grund, nicht umgekehrt.
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: QrImageView(
                              data: k.alsJson(),
                              size: 260,
                              semanticsLabel:
                                  'Einrichtungs-Code für ${k.anzeige}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          k.anzeige,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          k.url,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Der Code verbindet nur mit dem Server. Anmelden kann '
                          'sich danach nur, wer einen Zugang hat — den vergibt '
                          'der Kommandant.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
      ),
    );
  }
}
