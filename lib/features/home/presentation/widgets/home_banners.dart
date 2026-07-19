/// home_banners.dart – Hinweis-Banner oben auf dem Start-Dashboard:
/// App-Update verfügbar (GitHub Releases) und Feedback-Aufruf
/// (Feature-Wunsch/Bug-Report → Supabase → GitHub-Issue-Bot).
///
/// Beide Banner sind pro Sitzung wegklickbar (bewusst ohne Persistenz —
/// beim nächsten App-Start erscheinen sie wieder, solange relevant).
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider lebt in Riverpod 3 im legacy-Namespace.
import 'package:flutter_riverpod/legacy.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/update/update_check.dart';
import 'package:fwapp/features/feedback/data/feedback_repository.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Update-Banner für diese Sitzung ausgeblendet?
final updateBannerDismissedProvider = StateProvider<bool>((ref) => false);

/// Feedback-Banner für diese Sitzung ausgeblendet (oder Feedback gesendet)?
final feedbackBannerDismissedProvider = StateProvider<bool>((ref) => false);

/// Öffnet den Feedback-Dialog und sendet die Meldung; wird vom Banner und
/// von der „Mehr“-Kachel verwendet.
Future<void> showFeedbackDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<({FeedbackType type, String message})>(
    context: context,
    builder: (context) => const _FeedbackDialog(),
  );
  if (result == null) return;

  try {
    await submitFeedback(
      ref.read(supabaseClientProvider),
      type: result.type,
      message: result.message,
    );
    ref.read(feedbackBannerDismissedProvider.notifier).state = true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.type == FeedbackType.bug
              ? 'Danke für die Meldung — wir schauen uns das an! 🐛'
              : 'Danke für deinen Wunsch! 💡')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Senden fehlgeschlagen. Internetverbindung prüfen?')));
    }
  }
}

/// Banner-Spalte fürs Dashboard; rendert nichts, wenn kein Banner ansteht.
class HomeBanners extends ConsumerWidget {
  const HomeBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateInfo = ref.watch(updateInfoProvider).value;
    final updateDismissed = ref.watch(updateBannerDismissedProvider);
    final showUpdate = updateInfo != null && !updateDismissed;

    // Feedback braucht Server + Login (die Meldung landet in Supabase).
    final signedIn = ref.watch(supabaseReadyProvider) &&
        ref.watch(sessionStreamProvider).value != null;
    final showFeedback =
        signedIn && !ref.watch(feedbackBannerDismissedProvider);

    if (!showUpdate && !showFeedback) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUpdate)
          _BannerCard(
            emoji: '🔄',
            text: 'Update auf v${updateInfo.latestVersion} verfügbar',
            color: Theme.of(context).colorScheme.primaryContainer,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => _UpdateDialog(info: updateInfo),
            ),
            onDismiss: () =>
                ref.read(updateBannerDismissedProvider.notifier).state = true,
          ),
        if (showFeedback)
          _BannerCard(
            emoji: '💡',
            text: 'Wunsch oder Fehler melden',
            color: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () => showFeedbackDialog(context, ref),
            onDismiss: () => ref
                .read(feedbackBannerDismissedProvider.notifier)
                .state = true,
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Einzelner Banner im Karten-Look der App (tappbar, X zum Wegklicken).
class _BannerCard extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.emoji,
    required this.text,
    required this.color,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'Ausblenden',
          onPressed: onDismiss,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Update-Dialog: lädt die APK mit Fortschrittsbalken direkt in der App
/// herunter und öffnet anschließend den Android-Installer. Schlägt das
/// fehl, bleibt der Browser-Download als Fallback.
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdatePhase { idle, downloading, installing, error }

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  double _progress = 0;
  StreamSubscription<OtaEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _phase = _UpdatePhase.downloading);
    try {
      _subscription = OtaUpdate()
          .execute(widget.info.downloadUrl,
              destinationFilename: 'fwapp-update.apk')
          .listen(
        (event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              setState(() {
                _phase = _UpdatePhase.downloading;
                _progress = (double.tryParse(event.value ?? '') ?? 0) / 100;
              });
            case OtaStatus.INSTALLING:
              setState(() => _phase = _UpdatePhase.installing);
            default:
              setState(() => _phase = _UpdatePhase.error);
          }
        },
        onError: (Object _) {
          if (mounted) setState(() => _phase = _UpdatePhase.error);
        },
      );
    } catch (_) {
      setState(() => _phase = _UpdatePhase.error);
    }
  }

  Future<void> _browserFallback() async {
    await launchUrl(Uri.parse(widget.info.downloadUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: Text('Update auf v${info.latestVersion}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            switch (_phase) {
              _UpdatePhase.idle => const Text(
                  'Das Update lädt direkt in der App und öffnet dann den '
                  'Android-Installer — Datenbestand und Lernstand bleiben '
                  'erhalten. Beim ersten Mal fragt Android einmalig um '
                  'Erlaubnis.'),
              _UpdatePhase.downloading => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lade herunter … ${(_progress * 100).round()} %'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null),
                  ],
                ),
              _UpdatePhase.installing => const Text(
                  'Download fertig — Android fragt jetzt, ob die FWApp '
                  'aktualisiert werden soll. Einfach bestätigen!'),
              _UpdatePhase.error => const Text(
                  'Der Direkt-Download hat nicht geklappt. Du kannst das '
                  'Update stattdessen über den Browser laden — nach dem '
                  'Download in der Benachrichtigung auf die Datei tippen.'),
            },
            if (_phase == _UpdatePhase.idle &&
                info.releaseNotes != null &&
                info.releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Was ist neu:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(info.releaseNotes!.trim(),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        if (_phase == _UpdatePhase.idle) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Später'),
          ),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Jetzt aktualisieren'),
          ),
        ] else if (_phase == _UpdatePhase.error) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
          FilledButton.icon(
            onPressed: _browserFallback,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Im Browser laden'),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
      ],
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  FeedbackType _type = FeedbackType.feature;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bitte schreib ein paar Worte mehr. 🙂')));
      return;
    }
    Navigator.of(context).pop((type: _type, message: text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wünsch dir was!'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<FeedbackType>(
              segments: const [
                ButtonSegment(
                    value: FeedbackType.feature, label: Text('💡 Feature')),
                ButtonSegment(value: FeedbackType.bug, label: Text('🐛 Bug')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 12),
            Text(
              _type == FeedbackType.bug
                  ? 'Was funktioniert nicht? Beschreibe kurz, was du gemacht '
                      'hast und was stattdessen passiert ist.'
                  : 'Was fehlt dir, was nervt, was wäre praktisch? Jede Idee '
                      'landet direkt beim Entwickler.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _type == FeedbackType.bug
                    ? 'Was ist passiert?'
                    : 'Dein Wunsch',
                hintText: _type == FeedbackType.bug
                    ? 'z. B. „Beim Quiz bleibt das Bild schwarz“'
                    : 'z. B. „Eine Suche über alle Fahrzeuge wäre toll!“',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ℹ️ Dein Text erscheint zusammen mit deinem Nutzernamen '
              'öffentlich im GitHub-Projekt der App — bitte keine '
              'persönlichen Daten hineinschreiben.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Senden'),
        ),
      ],
    );
  }
}
