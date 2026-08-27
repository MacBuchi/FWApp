/// geraete_suche_providers.dart – Der durchsuchbare Bestand (Issue #180).
///
/// Der Index wird **einmal** gebaut und dann im Speicher gefiltert. Der
/// Grund ist die Tastatur: Gefiltert wird bei jedem Anschlag, und eine
/// Datenbankabfrage je Buchstabe wäre auf einem alten Diensthandy spürbar.
/// Ein Fuhrpark hat Hunderte Zuweisungen, keine Hunderttausende — der ganze
/// Bestand passt bequem in den Speicher.
///
/// Vier Abfragen, nicht N: Fahrzeuge, Fächer, Zuweisungen und Geräte kommen
/// jeweils vollständig, statt Fach für Fach nachgeladen zu werden.
library;

import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/search/domain/geraete_suche.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'geraete_suche_providers.g.dart';

/// Jedes Gerät einmal, mit allen Stellen, an denen es im Fuhrpark liegt.
///
/// Geräte **ohne** Fundort sind bewusst mit dabei: Die Suche soll „steht im
/// Katalog, ist aber nirgends verlastet" sagen können statt „nichts
/// gefunden". Bei einer Wehr, die ihre Beladung gerade erst erfasst, ist das
/// der häufigste Fall — und die nützlichste Auskunft.
@riverpod
Future<List<GeraetTreffer>> durchsuchbarerBestand(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);

  final fahrzeuge = {
    for (final v in await db.vehicleDao.getAll()) v.id: v,
  };
  final faecher = {
    for (final c in await db.compartmentDao.getAll()) c.id: c,
  };
  final zuweisungen = await db.assignmentDao.getAll();

  // Fundorte je Gerät sammeln. Ein Gerät kann in mehreren Fahrzeugen und
  // sogar in mehreren Fächern desselben Fahrzeugs liegen — beides ist im
  // Alltag normal (Schläuche) und beides gehört in die Antwort.
  final fundorte = <int, List<Fundort>>{};
  for (final z in zuweisungen) {
    final fach = faecher[z.compartmentId];
    if (fach == null) continue;
    final fahrzeug = fahrzeuge[fach.vehicleId];
    if (fahrzeug == null) continue;
    fundorte.putIfAbsent(z.equipmentId, () => []).add(Fundort(
          vehicleId: fahrzeug.id,
          fahrzeug: fahrzeug.name,
          compartmentId: fach.id,
          fach: FachAntwort.ausFach(fach),
          menge: z.quantity,
        ));
  }

  // Innerhalb eines Geräts nach Fahrzeug sortieren, damit die Fundorte in
  // derselben Reihenfolge stehen wie die Fahrzeugliste. Die Fächer kommen
  // schon in Einbaureihenfolge aus der Datenbank.
  for (final liste in fundorte.values) {
    liste.sort((a, b) => a.fahrzeug.compareTo(b.fahrzeug));
  }

  return [
    for (final eq in await db.equipmentDao.getAll())
      GeraetTreffer(
        equipmentId: eq.id,
        name: eq.name,
        kurzname: eq.shortName,
        bildPfad: eq.imagePath,
        funktionen: jsonToStringList(eq.equipmentFunctionsJson),
        fundorte: fundorte[eq.id] ?? const [],
      ),
  ];
}
