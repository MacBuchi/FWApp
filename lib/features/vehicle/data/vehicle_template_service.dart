/// vehicle_template_service.dart – Legt ein Fahrzeug aus einer Vorlage an
/// (Issue #55).
///
/// Geschäftslogik im Service, nicht im Widget (AGENTS.md). Alles in **einer**
/// Transaktion: Ein halb angelegtes Fahrzeug mit drei von acht Geräteräumen
/// wäre schlimmer als gar keines — der Gerätewart müsste erst aufräumen, bevor
/// er neu anfangen kann.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template.dart';

/// Was beim Anlegen aus der Vorlage entstanden ist.
class TemplateApplyResult {
  final int vehicleId;
  final int compartmentCount;

  /// Angelegte Beladungspositionen.
  final int itemCount;

  /// Katalog-IDs, zu denen kein Gerät gefunden wurde.
  ///
  /// Sollte leer sein — ein Test prüft die Vorlagen gegen den Katalog. Wenn
  /// hier doch etwas steht, ist die Bibliothek noch nicht geseedet, und der
  /// Aufrufer muss es sagen statt es zu verschlucken.
  final List<String> missingEquipment;

  const TemplateApplyResult({
    required this.vehicleId,
    required this.compartmentCount,
    required this.itemCount,
    this.missingEquipment = const [],
  });
}

class VehicleTemplateService {
  final AppDatabase db;

  /// Lädt den gebündelten Standard-Katalog; im Test ersetzbar.
  final Future<StandardCatalog> Function() catalogLoader;

  VehicleTemplateService(this.db, {this.catalogLoader = StandardCatalog.load});

  /// Legt Fahrzeug, Geräteräume und — wenn [withLoading] — die Beladung an.
  ///
  /// [name] überschreibt den Vorlagennamen; [imagePath] ist optional.
  /// Die Beladung landet gesammelt in [kUnassignedCompartmentLabel], **nicht**
  /// verteilt auf G1…G6: Die Raumzuordnung ist nicht genormt und unterscheidet
  /// sich je Wehr — sie zu erfinden wäre genau an der Stelle falsch, um die es
  /// beim Lernen geht.
  Future<TemplateApplyResult> apply(
    VehicleTemplate template, {
    required String name,
    String? licensePlate,
    String? imagePath,
    required bool withLoading,
  }) async {
    // Katalog VOR der Transaktion laden: rootBundle ist ein async-Spalt,
    // der nicht in eine DB-Transaktion gehört.
    final katalog = withLoading && template.hasLoading
        ? await catalogLoader()
        : StandardCatalog.empty();
    return db.transaction(() async {
      final vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(
          name: name,
          type: template.type,
          licensePlate: Value(licensePlate),
          imagePath: Value(imagePath),
        ),
      );

      for (final c in template.compartments) {
        await db.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(
            vehicleId: vehicleId,
            label: c.label,
            position: Value(c.position),
            // Verortung aus der Vorlage (Issue #144) — je Fach änderbar.
            seite: Value(c.seite),
            laengsposition: Value(c.laengsposition),
          ),
        );
      }

      if (!withLoading || !template.hasLoading) {
        return TemplateApplyResult(
          vehicleId: vehicleId,
          compartmentCount: template.compartments.length,
          itemCount: 0,
        );
      }

      // Sammelfach ans Ende, damit es die gewohnte G-Reihenfolge nicht stört.
      final unassignedId = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
          vehicleId: vehicleId,
          label: kUnassignedCompartmentLabel,
          position: Value(template.compartments.length),
        ),
      );

      final missing = <String>[];
      var placed = 0;
      for (final item in template.loading!.items) {
        final existing =
            await db.equipmentDao.getByLibraryId(item.equipmentId);
        // Nachlegen aus dem gebündelten Katalog: Auf Geräten, die schon
        // einmal zentral gezogen haben, überspringt der Seeder den Katalog
        // dauerhaft (der Pull ersetzt den lokalen Bestand). Ohne diesen
        // Rückgriff entstand ein Fahrzeug ohne ein einziges Gerät — still,
        // denn das Log liest im Gerätehaus niemand (Issue #86).
        final equipmentId = existing?.id ??
            await katalog.createEquipment(db, item.equipmentId);
        if (equipmentId == null) {
          missing.add(item.equipmentId);
          continue;
        }
        await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
            compartmentId: unassignedId,
            equipmentId: equipmentId,
            quantity: Value(item.quantity),
          ),
        );
        placed++;
      }

      if (missing.isNotEmpty) {
        appLog.w('Vorlage ${template.id}: ${missing.length} Positionen weder '
            'lokal noch im gebündelten Katalog — Vorlage und Katalog '
            'auseinandergelaufen?');
      }

      return TemplateApplyResult(
        vehicleId: vehicleId,
        compartmentCount: template.compartments.length + 1,
        itemCount: placed,
        missingEquipment: missing,
      );
    });
  }
}
