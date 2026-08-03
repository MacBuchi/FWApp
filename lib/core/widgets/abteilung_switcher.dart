/// abteilung_switcher.dart – Welche Abteilung ist gerade zu sehen, und wie
/// wechselt man sie? (Issue #96, Feld-Rückmeldung.)
///
/// Bis v1.11.0 lag beides in einer Kachel tief in den Einstellungen. Mit den
/// Mitgliedschaften aus Stufe ① (docs/NUTZERKONZEPT.md §2) ist der Wechsel
/// aber Alltag und kein Sonderfall mehr — also gehört er sichtbar in die
/// Leiste. Deshalb liegt der Wähler hier in `core` und nicht mehr im
/// Einstellungs-Feature: Ihn benutzen inzwischen Screens aus fünf Features.
///
/// Zwei Bausteine, eine Quelle:
/// - [AbteilungAction] — die Anzeige in der AppBar. Sie nennt die Abteilung
///   beim Namen (die Frage war „welche ist ausgewählt", nicht „bin ich
///   daheim") und hebt sich farbig ab, sobald es NICHT die Heimat ist.
/// - [showAbteilungPicker] — das Auswahl-Sheet samt Wechsel. Die einzige
///   Stelle, die den Wechsel auslöst; sie ruft [AbteilungSwitcher] auf, der
///   Persistenz und Erst-Pull erledigt.
///
/// Die eigene Abteilung wird intern als `null` geführt (angestammte
/// Datenbank-Datei, siehe abteilung_providers.dart) — übersetzt wird das an
/// genau einer Stelle, in [showAbteilungPicker].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/rollen.dart';
import 'package:fwapp/core/sync/temp_rechte_providers.dart';

/// Anzeige der aktuellen Abteilung als AppBar-Action, mit Wechsel per Tipp.
///
/// Unsichtbar, solange es nichts zu wählen gibt: im Lokalmodus, auf
/// Legacy-Servern (leere Liste) und bei genau einer lesbaren Abteilung —
/// dann ist die Frage „welche denn?" bereits beantwortet und die Leiste
/// bleibt frei.
class AbteilungAction extends ConsumerWidget {
  const AbteilungAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    if (abteilungen.length < 2) return const SizedBox.shrink();

    final own = ref.watch(myAbteilungIdProvider).value;
    final selectedId = ref.watch(selectedAbteilungIdProvider) ?? own;
    // Heimat noch nicht geladen und nichts gewählt: Wir wüssten nicht, was
    // wir anschreiben — lieber nichts als ein Sekundenbruchteil „ohne
    // Abteilung" in der Leiste.
    if (selectedId == null) return const SizedBox.shrink();

    final selected = abteilungen.where((a) => a.id == selectedId).firstOrNull;
    final istHeimat = selectedId == own;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = selected?.name ?? abteilungsName(selectedId, abteilungen);

    // Der Farbwechsel ist die eigentliche Antwort auf „sehe ich meine
    // Heim-Abteilung?" — Form und Farbe tragen sie zusammen, damit sie auch
    // ohne Farbunterscheidung (Icon) ankommt.
    final fg = istHeimat ? scheme.onSurfaceVariant : scheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Tooltip(
        message: istHeimat
            ? '$name — deine Abteilung. Zum Wechseln tippen.'
            : '$name — Schwester-Abteilung. Zum Wechseln tippen.',
        child: Material(
          color: istHeimat ? Colors.transparent : scheme.tertiaryContainer,
          shape: StadiumBorder(
            side: BorderSide(
              color: istHeimat ? scheme.outlineVariant : Colors.transparent,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showAbteilungPicker(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    istHeimat ? Icons.home_work_outlined : Icons.visibility,
                    size: 18,
                    color: fg,
                  ),
                  const SizedBox(width: 6),
                  // Der Name darf die Leiste nicht sprengen: Auf dem quer
                  // liegenden Testgerät sind 683 dp gesamt, und daneben
                  // stehen noch Suchen/Hinzufügen.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 104),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Öffnet die Abteilungswahl und führt den Wechsel aus.
///
/// Tut nichts, wenn die schon angezeigte Abteilung gewählt wird — ein Wechsel
/// zieht den kompletten Bestand neu, das ist für einen Fehlgriff zu teuer.
Future<void> showAbteilungPicker(BuildContext context, WidgetRef ref) async {
  final own = ref.read(myAbteilungIdProvider).value;
  final target = await showModalBottomSheet<AbteilungInfo>(
    context: context,
    // PFLICHT, nicht Geschmack: Ohne den Wurzel-Navigator landet das Sheet im
    // verschachtelten Navigator der ShellRoute, und dann liegt die
    // Navigationsleiste ÜBER seiner Sperrfläche — ein Tipp knapp unter dem
    // Sheet bricht die Auswahl ab und wechselt zugleich den Tab. Im Browser
    // erlebt (Issue #96); dieselbe Verschachtelung wie bei #79.
    useRootNavigator: true,
    // Ohne isScrollControlled kappt Flutter das Sheet bei 9/16 der Höhe. Auf
    // dem quer liegenden Testgerät (411 dp hoch) sind das 231 dp — schon bei
    // zwei Abteilungen steht die zweite auf der Kante. Die Gesamtwehr ist auf
    // mehr angelegt, also gilt die Kappung erst bei 80 %.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (context) => _AbteilungSheet(own: own),
  );
  if (target == null || !context.mounted) return;

  final aktuell = ref.read(selectedAbteilungIdProvider) ?? own;
  if (target.id == aktuell) return;

  final messenger = ScaffoldMessenger.of(context);
  // Eigene Abteilung = null: Sie behält die angestammte Datenbank-Datei.
  await ref
      .read(abteilungSwitcherProvider)
      .switchTo(target.id == own ? null : target.id);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        target.id == own
            ? 'Zurück in deiner Abteilung.'
            : '${target.name}: Der Bestand wird geladen …',
      ),
    ),
  );
}

/// Was der Angemeldete in [a] darf, als Zeile für Kachel und Sheet.
///
/// Auf Alt-Servern ohne Mitgliedschaften bleibt es beim alten Wortlaut — dort
/// IST die Schwester-Sicht lesend, die Aussage wäre also nicht falsch, nur
/// nicht mehr die ganze Wahrheit.
String abteilungsRechteText(
  AbteilungInfo a, {
  required bool istHeimat,
  required Map<String, String>? mitgliedschaften,
  required Set<String>? kommandierteGesamtwehren,
  Set<String>? temporaereRechte,
}) {
  final wo = istHeimat ? 'Deine Abteilung' : 'Schwester-Abteilung';
  if (mitgliedschaften == null) {
    return istHeimat ? wo : '$wo — nur lesen';
  }
  final rolle = schreibrolleInAbteilung(
    abteilungId: a.id,
    gesamtwehrId: a.gesamtwehrId,
    mitgliedschaften: mitgliedschaften,
    kommandierteGesamtwehren: kommandierteGesamtwehren,
    temporaereRechte: temporaereRechte,
  );
  return rolle == null ? '$wo — nur lesen' : '$wo — $rolle';
}

/// Anzeigetitel einer Abteilung: Name, bei mehreren Gesamtwehren mit Kontext.
String abteilungsTitel(AbteilungInfo a) =>
    a.gesamtwehrName == null ? a.name : '${a.name} · ${a.gesamtwehrName}';

class _AbteilungSheet extends ConsumerWidget {
  const _AbteilungSheet({required this.own});

  final String? own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    final selectedId = ref.watch(selectedAbteilungIdProvider) ?? own;
    final mitgliedschaften = ref.watch(meineMitgliedschaftenProvider).value;
    final kommandiert = ref.watch(meineKommandoGesamtwehrenProvider).value;
    // Befristete Rechte erscheinen hier wie eine Schreibrolle, nur mit dem
    // Zusatz „(befristet)" — im Gerätehaus ist der Unterschied genau der,
    // der zählt (#100).
    final temporaer =
        ref.watch(meineTemporaerenRechteProvider).value?.keys.toSet();
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Abteilung wählen',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Ansehen und lernen kannst du überall. Ob du auch bearbeiten '
                'darfst, steht bei jeder Abteilung.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final a in abteilungen)
              ListTile(
                leading: Icon(
                  a.id == own ? Icons.home_work : Icons.visibility,
                  color: a.id == selectedId ? theme.colorScheme.primary : null,
                ),
                title: Text(abteilungsTitel(a)),
                subtitle: Text(
                  abteilungsRechteText(
                    a,
                    istHeimat: a.id == own,
                    mitgliedschaften: mitgliedschaften,
                    kommandierteGesamtwehren: kommandiert,
                    temporaereRechte: temporaer,
                  ),
                ),
                trailing: a.id == selectedId
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, a),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
