/// anhang_providers.dart – Unterlagen am Fahrzeug (Issue #182).
///
/// ⚠️ **Bewusst OHNE Codegen.** `riverpod_generator` bricht mit
/// `InvalidTypeException` ab, sobald ein Provider eine Drift-Datenklasse
/// zurückgibt — die liegt in einer `part`-Datei, und der Generator bekommt
/// den Typ nicht zu fassen. `dashboard_providers.dart` löst dasselbe Problem
/// seit jeher genauso. Wer hier auf `@riverpod` umstellt, macht den Build
/// rot, nicht schöner.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';

final anhangSpeicherProvider = Provider<AnhangSpeicher>((ref) => AnhangSpeicher(
      db: ref.watch(appDatabaseProvider),
      client: ref.watch(supabaseClientProvider),
    ));

/// Die Anhänge eines Fahrzeugs, live aus der **lokalen** Datenbank.
///
/// Lokal und nicht vom Server: Was hier steht, ist auch ohne Netz da — und
/// genau das ist die Zusage dieses Features.
final fahrzeugAnhaengeProvider =
    StreamProvider.family<List<VehicleAttachmentData>, int>((ref, vehicleId) =>
        ref.watch(attachmentDaoProvider).watchByVehicle(vehicleId));

/// Die Abteilung, in deren Ordner die Dateien landen.
///
/// Erst die gewählte (Quer-Sicht auf Schwester-Abteilungen), sonst die
/// eigene — dieselbe Reihenfolge wie überall sonst in der App.
final anhangAbteilungProvider = Provider<String?>((ref) =>
    ref.watch(selectedAbteilungIdProvider) ??
    ref.watch(myAbteilungIdProvider).value);

/// Holt die Anhang-Zeilen der Abteilung und reicht nach, was noch nicht
/// hochgeladen ist.
///
/// Läuft überall dort, wo auch der Bestand gezogen wird — Start, „Jetzt
/// aktualisieren", Abteilungswechsel. Bewusst NICHT mit dem Snapshot
/// verwoben: Der ersetzt die Tabellen der Abteilung, und diese hier darf er
/// nicht anfassen (siehe `kSyncedTables`).
///
/// Ohne Server oder ohne Abteilung ein No-op — die App läuft lokal weiter.
/// Nimmt die beiden Werte statt eines `Ref`: Aufgerufen wird sie sowohl aus
/// einem Provider (`Ref`) als auch aus einem Widget (`WidgetRef`), und die
/// beiden sind in Riverpod 3 keine gemeinsame Schnittstelle mehr.
Future<void> anhaengeSynchronisieren(
    AnhangSpeicher speicher, String? abteilung) async {
  if (abteilung == null) return;
  await speicher.zieheAnhaenge(abteilung);
  await speicher.nachreichen(abteilungId: abteilung);
}
