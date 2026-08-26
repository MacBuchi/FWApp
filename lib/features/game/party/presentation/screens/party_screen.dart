/// party_screen.dart – Party-Modus: ein Handy, mehrere Spieler (Issue #160).
///
/// **Warum am Tisch und nicht über das Netz:** Es gibt keinen Push, mit dem
/// ein Handy erführe, dass es dran ist, und der Sync ist ein
/// Einzelschreiber-Snapshot für den Bestand — Spielstand zwischen Geräten
/// wäre eine neue Infrastruktur. Der Anlass ist ohnehin der
/// Kameradschaftsabend: Alle sitzen an einem Tisch, das Handy geht reihum.
///
/// Der Übergabe-Schirm zwischen zwei Zügen ist deshalb kein Schmuck, sondern
/// die halbe Mechanik — ohne ihn liest der Vorgänger die Frage mit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';
import 'package:fwapp/features/game/party/presentation/providers/party_providers.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

/// Wie viele Fragen ein Spieler bekommen kann.
const kFragenProSpieler = [3, 5, 8];

const kMaxSpieler = 8;

/// „Anna und Ben", „Anna, Ben und Cem" — für die Sieger-Zeile bei
/// Gleichstand.
String namenAufzaehlung(List<PartySpieler> spieler) {
  final namen = spieler.map((s) => s.name).toList();
  if (namen.length <= 1) return namen.join();
  return '${namen.sublist(0, namen.length - 1).join(', ')} und ${namen.last}';
}

class PartyScreen extends ConsumerStatefulWidget {
  const PartyScreen({super.key});

  @override
  ConsumerState<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<PartyScreen> {
  final _nameController = TextEditingController();
  final List<String> _namen = [];
  Vehicle? _fahrzeug;
  int _fragenProSpieler = 3;
  bool _trinkspiel = false;
  bool _laedt = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(partySpielProvider);
    if (stand == null) return _aufbau();
    if (stand.beendet) return _ergebnis(stand);
    if (stand.uebergabe) return _uebergabe(stand);
    return _frage(stand);
  }

  // ── Aufbau ────────────────────────────────────────────────────────────

  void _spielerHinzufuegen() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _namen.length >= kMaxSpieler) return;
    // Namensdopplung wäre in der Rangliste nicht auflösbar.
    if (_namen.any((n) => n.toLowerCase() == name.toLowerCase())) return;
    setState(() {
      _namen.add(name);
      _nameController.clear();
    });
  }

  Future<void> _starten() async {
    setState(() => _laedt = true);
    final klappt = await ref.read(partySpielProvider.notifier).starte(
          namen: _namen,
          fragenProSpieler: _fragenProSpieler,
          trinkspiel: _trinkspiel,
          vehicleId: _fahrzeug?.id,
        );
    if (!mounted) return;
    setState(() => _laedt = false);
    if (!klappt) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Keine Fragen verfügbar. Bitte zuerst ein Fahrzeug '
              'mit Beladung anlegen.')));
    }
  }

  Widget _aufbau() {
    final fahrzeuge = ref.watch(vehicleListStreamProvider);
    final genugSpieler = _namen.length >= 2;
    return Scaffold(
      appBar: AppBar(title: const Text('Party-Modus')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ein Handy, alle am Tisch. Es geht reihum: Wer dran ist, bekommt '
            'das Handy, beantwortet seine Frage und gibt weiter.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Spieler hinzufügen',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _spielerHinzufuegen(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.person_add),
                tooltip: 'Spieler hinzufügen',
                onPressed: _spielerHinzufuegen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _namen
                .map((n) => Chip(
                      label: Text(n),
                      onDeleted: () => setState(() => _namen.remove(n)),
                    ))
                .toList(),
          ),
          if (!genugSpieler)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Mindestens zwei Spieler.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 20),
          fahrzeuge.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Fehler: $e'),
            // `isExpanded` und `ellipsis` sind Pflicht, keine Kosmetik: Ein
            // echter Fahrzeugname („HLF 20/16 Florian Musterstadt 1/44")
            // ließ die Auswahl auf einem Handy um knapp 300 Pixel überlaufen
            // — die gestreifte Fehlerfläche statt des Namens.
            data: (liste) => DropdownButtonFormField<Vehicle?>(
              initialValue: _fahrzeug,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Fahrzeug (optional)',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Alle Fahrzeuge')),
                ...liste.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _fahrzeug = v),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Fragen je Spieler'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: kFragenProSpieler
                .map((n) =>
                    ButtonSegment(value: n, label: Text('$n')))
                .toList(),
            selected: {_fragenProSpieler},
            onSelectionChanged: (s) =>
                setState(() => _fragenProSpieler = s.first),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Trinkspiel'),
            subtitle: const Text(
                'Bei einer falschen Antwort: ein Schluck — oder die Aufgabe, '
                'die das Spiel stattdessen vorschlägt.'),
            value: _trinkspiel,
            onChanged: (v) => setState(() => _trinkspiel = v),
          ),
          if (_trinkspiel)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Wer heute Bereitschaft hat, nimmt die Aufgabe.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _laedt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('Losgeht\'s'),
            onPressed: genugSpieler && !_laedt ? _starten : null,
          ),
        ],
      ),
    );
  }

  // ── Übergabe ──────────────────────────────────────────────────────────

  Widget _uebergabe(PartyStand stand) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // Die Kategorie steht mit im Titel: Seit Issue #172 bleibt eine
        // Runde bei einer Art Frage, und was niemand sieht, ist am Tisch
        // keine Regel, sondern Zufall. Verraten wird damit nichts —
        // „Wo liegt was?" gilt für jedes Fach jedes Fahrzeugs.
        title:
            Text('Runde ${stand.zugNummer} · ${stand.frage.art.bezeichnung}'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => ref.read(partySpielProvider.notifier).beenden(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_right_alt,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Handy weitergeben an'),
              const SizedBox(height: 8),
              Text(
                stand.amZug.name,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text('Bereit'),
                onPressed: () =>
                    ref.read(partySpielProvider.notifier).bereit(),
              ),
              const SizedBox(height: 32),
              _punktestand(stand),
            ],
          ),
        ),
      ),
    );
  }

  Widget _punktestand(PartyStand stand) => Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: stand.rangliste
            .map((s) => Text('${s.name} ${s.punkte}',
                style: Theme.of(context).textTheme.bodySmall))
            .toList(),
      );

  // ── Frage ─────────────────────────────────────────────────────────────

  Widget _frage(PartyStand stand) {
    final theme = Theme.of(context);
    final frage = stand.frage;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
            '${stand.amZug.name} · ${stand.index + 1}/${stand.fragen.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: stand.index / stand.fragen.length),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (frage.bildPfad != null || frage.funktionen.isNotEmpty)
            EquipmentAvatar(
              imagePath: frage.bildPfad,
              functions: frage.funktionen,
              size: 150,
              width: double.infinity,
            ),
          if (frage.kopfzeile != null) ...[
            const SizedBox(height: 8),
            Text(frage.kopfzeile!,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
          // Das Fahrzeug gehört über die Antworten, nicht in die Auflösung:
          // Zur Wahl stehen die Fächer eines bestimmten Wagens, und wer den
          // nicht kennt, rät (Issue #172). Als eigene Zeile statt im
          // Fragetext, weil Namen wie „HLF 20/16 Florian 1/44" den Satz
          // sonst unlesbar machen.
          if (frage.fahrzeug != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Chip(
                avatar: Icon(Icons.fire_truck,
                    size: 18, color: theme.colorScheme.onSecondaryContainer),
                label: Text(frage.fahrzeug!),
                backgroundColor: theme.colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(frage.text,
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ...List.generate(frage.antworten.length, (i) {
            final antwort = frage.antworten[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _flaeche(stand, i),
                    side: BorderSide(color: _rand(stand, i), width: 1.5),
                    // Beantwortete Knöpfe sind abgeschaltet, und Material
                    // blasst abgeschaltete Beschriftungen aus. Am Handy in
                    // der eigenen Hand geht das durch; hier schaut die halbe
                    // Runde von der anderen Tischseite zu — die Auflösung
                    // muss lesbar bleiben.
                    disabledForegroundColor: _schrift(stand, i),
                    // Waagerecht ausdrücklich: `symmetric(vertical:)` setzt
                    // die Seiten auf 0, und der Farbpunkt klebte am Rand.
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                  onPressed: stand.beantwortet
                      ? null
                      : () =>
                          ref.read(partySpielProvider.notifier).antworte(i),
                  child: antwort.fach != null
                      ? FachAntwortInhalt(antwort: antwort.fach!)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(antwort.text)),
                ),
              ),
            );
          }),
          if (stand.beantwortet) ...[
            const SizedBox(height: 16),
            _aufloesung(stand),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(partySpielProvider.notifier).weiter(),
              child: Text(stand.index + 1 < stand.fragen.length
                  ? 'Weitergeben'
                  : 'Ergebnis'),
            ),
          ],
        ],
      ),
    );
  }

  Color? _flaeche(PartyStand stand, int i) {
    if (!stand.beantwortet) return null;
    if (stand.frage.istRichtig(i)) {
      return Colors.green.withValues(alpha: 0.15);
    }
    if (stand.gewaehlt == i) return Colors.red.withValues(alpha: 0.15);
    return null;
  }

  Color _schrift(PartyStand stand, int i) {
    if (!stand.beantwortet) return Theme.of(context).colorScheme.onSurface;
    if (stand.frage.istRichtig(i)) return Colors.green.shade900;
    if (stand.gewaehlt == i) return Colors.red.shade900;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _rand(PartyStand stand, int i) {
    if (!stand.beantwortet) return Colors.grey;
    if (stand.frage.istRichtig(i)) return Colors.green;
    if (stand.gewaehlt == i) return Colors.red;
    return Colors.grey;
  }

  Widget _aufloesung(PartyStand stand) {
    final theme = Theme.of(context);
    final richtig = stand.frage.istRichtig(stand.gewaehlt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(richtig ? Icons.check_circle : Icons.cancel,
                color: richtig ? Colors.green.shade700 : Colors.red.shade700),
            const SizedBox(width: 8),
            Text(richtig ? 'Richtig' : 'Daneben',
                style: theme.textTheme.titleMedium),
          ],
        ),
        if (stand.frage.erklaerung != null) ...[
          const SizedBox(height: 8),
          Text(stand.frage.erklaerung!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        if (stand.aufgabe != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DefaultTextStyle.merge(
                style:
                    TextStyle(color: theme.colorScheme.onTertiaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ein Schluck — oder:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(stand.aufgabe!),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Ergebnis ──────────────────────────────────────────────────────────

  Widget _ergebnis(PartyStand stand) {
    final theme = Theme.of(context);
    final rang = stand.rangliste;
    final sieger = stand.sieger;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ergebnis'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
              sieger.length == 1
                  ? 'Sieger: ${sieger.single.name}'
                  : 'Unentschieden: ${namenAufzaehlung(sieger)}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ...rang.map((s) {
            final platz = stand.platz(s);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: platz == 1
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: platz == 1
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                child: Text('$platz'),
              ),
              title: Text(s.name),
              subtitle: stand.trinkspiel && s.konsequenzen > 0
                  ? Text('${s.konsequenzen}× Schluck oder Aufgabe')
                  : null,
              trailing:
                  Text('${s.punkte}', style: theme.textTheme.titleLarge),
            );
          }),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.replay),
            label: const Text('Nochmal, gleiche Runde'),
            onPressed: _laedt ? null : _starten,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.read(partySpielProvider.notifier).beenden(),
            child: const Text('Spieler ändern'),
          ),
        ],
      ),
    );
  }
}
