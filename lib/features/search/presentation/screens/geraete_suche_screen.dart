/// geraete_suche_screen.dart – „Wo liegt das?" (Issue #180).
///
/// Zwei Reichweiten in einem Schirm, weil es dieselbe Frage ist: der ganze
/// Fuhrpark der Abteilung, oder ein einzelnes Fahrzeug. Womit er aufgeht,
/// hängt daran, wo man herkam — vom Fahrzeug aus ist dieses Fahrzeug
/// vorgewählt.
///
/// Die Abteilung braucht keine eigene Bedingung: Die App führt **je
/// Abteilung eine eigene Datenbankdatei** (`AppDatabase.create`), der lokale
/// Bestand *ist* also der Fuhrpark der eigenen Abteilung.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/search/domain/geraete_suche.dart';
import 'package:fwapp/features/search/presentation/providers/geraete_suche_providers.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:go_router/go_router.dart';

class GeraeteSucheScreen extends ConsumerStatefulWidget {
  /// Vorgewähltes Fahrzeug, `null` heißt ganzer Fuhrpark.
  final int? vehicleId;

  const GeraeteSucheScreen({super.key, this.vehicleId});

  @override
  ConsumerState<GeraeteSucheScreen> createState() => _GeraeteSucheScreenState();
}

class _GeraeteSucheScreenState extends ConsumerState<GeraeteSucheScreen> {
  final _controller = TextEditingController();
  String _eingabe = '';
  late int? _fahrzeugId = widget.vehicleId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bestand = ref.watch(durchsuchbarerBestandProvider);
    final fahrzeuge = ref.watch(vehicleListStreamProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Gerätesuche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Gerät suchen, z. B. „Spreizer“',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _eingabe.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Eingabe löschen',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _eingabe = '');
                        },
                      ),
              ),
              onChanged: (wert) => setState(() => _eingabe = wert),
            ),
          ),
          _fahrzeugWahl(fahrzeuge),
          Expanded(
            child: bestand.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (alle) => _ergebnis(sucheGeraete(
                bestand: alle,
                eingabe: _eingabe,
                vehicleId: _fahrzeugId,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fahrzeugWahl(List<Vehicle> fahrzeuge) {
    // ⚠️ Nur eine Auswahl anzeigen, die es in der Liste auch GIBT.
    // `DropdownButton` bricht mit einer Zusicherung ab, wenn sein Wert zu
    // keinem Eintrag passt — und genau das ist der Normalfall beim ersten
    // Bild: Der Schirm wird mit vorgewähltem Fahrzeug geöffnet, während der
    // Fahrzeug-Strom noch nichts geliefert hat. Dasselbe greift, wenn das
    // Fahrzeug inzwischen gelöscht wurde.
    final gewaehlt =
        fahrzeuge.any((v) => v.id == _fahrzeugId) ? _fahrzeugId : null;
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        // `isExpanded` und `ellipsis`: Ein echter Fahrzeugname („HLF 20/16
        // Florian Musterstadt 1/44") sprengt das Feld sonst auf einem Handy
        // (dort gefunden: Issue #172).
        child: DropdownButtonFormField<int?>(
          initialValue: gewaehlt,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Wo suchen?',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('Ganzer Fuhrpark')),
            ...fahrzeuge.map((v) => DropdownMenuItem(
                  value: v.id,
                  child: Text(v.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (wert) => setState(() => _fahrzeugId = wert),
        ));
  }

  Widget _ergebnis(SucheErgebnis ergebnis) {
    if (_eingabe.trim().isEmpty) {
      return _hinweis(
        Icons.search,
        _fahrzeugId == null
            ? 'Tippe einen Gerätenamen ein — die Suche sagt dir, in welchem '
                'Fahrzeug und in welchem Fach es liegt.'
            : 'Tippe einen Gerätenamen ein. Liegt er nicht in diesem '
                'Fahrzeug, sagt die Suche, wo sonst.',
      );
    }
    if (ergebnis.istLeer) {
      return _hinweis(Icons.search_off,
          'Kein Gerät gefunden, das auf „${_eingabe.trim()}“ passt.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        ...ergebnis.treffer.map(_karte),
        if (ergebnis.woanders.isNotEmpty) ...[
          // Der eigentliche Nutzen am Fahrzeug: „nicht hier, aber im LF 20,
          // Fach G1" ist eine Antwort — „keine Treffer" wäre eine Lüge.
          _abschnitt('Nicht in diesem Fahrzeug — aber im Fuhrpark'),
          ...ergebnis.woanders.map(_karte),
        ],
        if (ergebnis.nirgends.isNotEmpty) ...[
          _abschnitt('Im Katalog, aber nirgends verlastet'),
          ...ergebnis.nirgends.map(_karte),
        ],
      ],
    );
  }

  Widget _abschnitt(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );

  Widget _hinweis(IconData symbol, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbol,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _karte(GeraetTreffer geraet) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EquipmentAvatar(
                  imagePath: geraet.bildPfad,
                  functions: geraet.funktionen,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(geraet.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (geraet.kurzname != null &&
                          geraet.kurzname!.isNotEmpty)
                        Text(geraet.kurzname!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Gerät ansehen',
                  onPressed: () =>
                      context.push('/equipment/${geraet.equipmentId}'),
                ),
              ],
            ),
            if (!geraet.istVerlastet)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'In keinem Fahrzeug eingetragen.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ...geraet.fundorte.map((ort) => _fundort(geraet, ort)),
          ],
        ),
      ),
    );
  }

  Widget _fundort(GeraetTreffer geraet, Fundort ort) {
    final theme = Theme.of(context);
    // Das Fahrzeug steht nur dann dabei, wenn es etwas zu unterscheiden gibt:
    // In der Fahrzeug-Suche wäre bei jedem Treffer derselbe Name — Lärm.
    final zeigeFahrzeug = _fahrzeugId == null || ort.vehicleId != _fahrzeugId;
    return InkWell(
      onTap: () => context.push('/vehicles/${ort.vehicleId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (zeigeFahrzeug)
                    Row(
                      children: [
                        Icon(Icons.fire_truck,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(ort.fahrzeug,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: zeigeFahrzeug ? 4 : 0),
                    child: FachAntwortInhalt(antwort: ort.fach),
                  ),
                ],
              ),
            ),
            // Die Menge nur, wenn es mehr als eines ist: „1×" an jedem
            // Treffer wäre eine Spalte ohne Aussage.
            if (ort.menge > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${ort.menge}×',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
