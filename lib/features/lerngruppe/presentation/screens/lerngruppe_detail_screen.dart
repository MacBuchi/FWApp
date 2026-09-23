/// lerngruppe_detail_screen.dart – Eine Lerngruppe: Laufzeit, Code zum
/// Weitergeben, wer drin ist, verlassen (Issue #136).
///
/// Liest die Gruppe aus [meineLerngruppenProvider] statt sie als `extra`
/// mitzubekommen: So überlebt die Seite ein Neuladen im Browser, und nach
/// dem Verlassen steht dort ehrlich „nicht mehr dabei" statt einer Gruppe,
/// die es für einen gar nicht mehr gibt.
///
/// Wochenaufgabe und Rangliste (Teil D von #136): Die Aufgabe kommt vom
/// Server (abgeleitet, nicht gespeichert), die Werte aus
/// `lerngruppen_wertungen`, gerechnet wird in `wertung.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sharing/teilen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/domain/wertung.dart';
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

class _Inhalt extends ConsumerStatefulWidget {
  final Lerngruppe gruppe;
  const _Inhalt({required this.gruppe});

  @override
  ConsumerState<_Inhalt> createState() => _InhaltState();
}

class _InhaltState extends ConsumerState<_Inhalt> {
  @override
  void initState() {
    super.initState();
    // Beim Öffnen einmal melden: Wer gerade gespielt hat und direkt
    // hierher kommt, soll sich schon in der Rangliste sehen — der Melder im
    // Hintergrund ist vielleicht noch unterwegs.
    unawaited(_melden());
  }

  Future<void> _melden() async {
    final dienst = ref.read(lerngruppeServiceProvider);
    if (dienst == null) return;
    try {
      await dienst.meldeWochenwerte();
    } catch (e) {
      appLog.i('Wochenwert beim Öffnen nicht gemeldet', error: e);
    }
  }

  Future<void> _aktualisieren() async {
    await _melden();
    final id = widget.gruppe.id;
    ref.invalidate(lerngruppenMitgliederProvider(id));
    ref.invalidate(lerngruppeWochenaufgabeProvider(id));
    ref.invalidate(lerngruppenWertungenProvider(id));
    await ref.read(lerngruppenWertungenProvider(id).future);
  }

  @override
  Widget build(BuildContext context) {
    final gruppe = widget.gruppe;
    final theme = Theme.of(context);
    final heute = DateTime.now();
    final laeuft = gruppe.laeuftAm(heute);
    final mitglieder = ref.watch(lerngruppenMitgliederProvider(gruppe.id));
    final aufgabe =
        laeuft
            ? ref.watch(lerngruppeWochenaufgabeProvider(gruppe.id)).value
            : null;
    final wertungen =
        ref.watch(lerngruppenWertungenProvider(gruppe.id)).value ?? const [];
    final ichId = ref.watch(sessionStreamProvider).value?.user.id;

    return RefreshIndicator(
      onRefresh: _aktualisieren,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(gruppe.laufzeitText(heute), style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          if (aufgabe != null) ...[
            _AufgabenKarte(
              aufgabe: aufgabe,
              eigenerWert:
                  wertungen
                      .where(
                        (w) =>
                            w.userId == ichId &&
                            DateUtils.isSameDay(w.woche, aufgabe.woche),
                      )
                      .firstOrNull
                      ?.wert,
            ),
            const SizedBox(height: 16),
          ],
          // Der Code nur, solange er noch etwas nützt: Einer beendeten
          // Gruppe tritt der Server nicht mehr bei.
          if (laeuft) _CodeKarte(gruppe: gruppe),
          const SizedBox(height: 24),
          ...mitglieder.when(
            loading:
                () => const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
            error: (e, _) => [Text(lerngruppeFehler(e))],
            data: (liste) {
              final namen = {for (final m in liste) m.userId: m};
              final ids = [for (final m in liste) m.userId];
              return [
                if (aufgabe != null) ...[
                  _Rangliste(
                    titel: 'Diese Woche · ${aufgabe.modus.titel}',
                    einheit: '%',
                    zeilen: wochenRangliste(ids, wertungen, aufgabe.woche),
                    namen: namen,
                    ichId: ichId,
                  ),
                  const SizedBox(height: 16),
                ],
                _Rangliste(
                  titel: 'Gesamt',
                  untertitel: 'Summe der Wochenwerte',
                  einheit: 'Pkt.',
                  zeilen: gesamtRangliste(ids, wertungen),
                  namen: namen,
                  ichId: ichId,
                ),
                if (liste.length == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Noch bist du allein. Gib den Code weiter!',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ];
            },
          ),
          const SizedBox(height: 24),
          // Ehrlich sagen, was geteilt wird — und was nicht. Das ist der
          // erste Weg, auf dem Lernergebnisse das Gerät verlassen.
          Text(
            'Gezählt wird der Schnitt deiner letzten zwei Runden der Woche '
            'im Modus der Wochenaufgabe. Die Gruppe sieht nur diese eine '
            'Zahl — nicht, welche Fragen du falsch hattest, und nichts aus '
            'den anderen Modi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wo die Wochenaufgabe gespielt wird. Die Pfade stehen hier und nicht im
/// Domain-Modell, weil sie zur Navigation gehören.
const _pfade = {
  Lernmodus.fachQuiz: '/game/compartment-quiz',
  Lernmodus.bildErkennung: '/game/image-quiz',
  Lernmodus.woLiegts: '/game/cutaway-quiz',
  Lernmodus.dragDrop: '/game/drag-drop',
};

class _AufgabenKarte extends StatelessWidget {
  final Wochenaufgabe aufgabe;
  final int? eigenerWert;
  const _AufgabenKarte({required this.aufgabe, this.eigenerWert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wert = eigenerWert;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wochenaufgabe', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(aufgabe.modus.titel, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              wert == null
                  ? 'Du hast diese Woche noch keine Runde gespielt. '
                      'Zeit bis Sonntag.'
                  : 'Dein Wert diese Woche: $wert %. Noch eine Runde kann '
                      'ihn verbessern — oder verschlechtern.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jetzt spielen'),
              onPressed: () => context.push(_pfade[aufgabe.modus]!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rangliste extends StatelessWidget {
  final String titel;
  final String? untertitel;
  final String einheit;
  final List<Platzierung> zeilen;
  final Map<String, LerngruppenMitglied> namen;
  final String? ichId;

  const _Rangliste({
    required this.titel,
    this.untertitel,
    required this.einheit,
    required this.zeilen,
    required this.namen,
    required this.ichId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: theme.textTheme.titleSmall),
        if (untertitel != null)
          Text(untertitel!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        for (final z in zeilen)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 72,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      z.platz == null ? '–' : '${z.platz}.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FwAvatar(
                    konfiguration: AvatarKonfiguration.dekodiert(
                      namen[z.userId]?.avatar,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              '${namen[z.userId]?.anzeigeName ?? 'Unbenannt'}'
              '${z.userId == ichId ? ' (du)' : ''}',
            ),
            trailing: Text(
              z.punkte == null ? 'noch nicht' : '${z.punkte} $einheit',
              style:
                  z.punkte == null
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.titleMedium,
            ),
          ),
      ],
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
