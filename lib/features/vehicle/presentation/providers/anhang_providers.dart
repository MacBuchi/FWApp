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
