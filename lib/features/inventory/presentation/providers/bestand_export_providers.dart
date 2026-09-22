/// bestand_export_providers.dart – Den Bestand einsammeln und weitergeben
/// (Issue #176).
///
/// Bewusst OHNE Codegen, wie die Nachbarn: `riverpod_generator` bricht mit
/// `InvalidTypeException` ab, sobald ein Provider eine Drift-Datenklasse
/// berührt (`anhang_providers.dart`, Kopf).
///
/// Die Datei entsteht aus der **lokalen** Datenbank, nicht vom Server. Das
/// ist keine Bequemlichkeit: Ein Verzeichnis, das nur mit Netz zu bekommen
/// ist, fehlt genau dann, wenn jemand es braucht — und der Bestand steht
/// hier ohnehin vollständig.
library;

import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/data/bestand_export.dart';

/// Sammelt alles ein und baut die CSV-Datei.
///
/// Sieben Abfragen für die ganze Wehr statt einer je Gerät: Bei hundertzehn
/// Geräten wäre das Gegenteil hundertzehnmal langsamer, und der Export läuft
/// auf einem Handy.
Future<String> bestandAlsCsv(AppDatabase db) async => bestandCsv(
  fahrzeuge: await db.vehicleDao.getAll(),
  faecher: await db.compartmentDao.getAll(),
  zuordnungen: await db.assignmentDao.getAll(),
  geraete: await db.equipmentDao.getAll(),
  einheiten: await db.inspectionDao.getAllInstances(),
  codes: await db.tagDao.alleTags(),
  pruefungen: await db.inspectionDao.getAllSchedules(),
);
