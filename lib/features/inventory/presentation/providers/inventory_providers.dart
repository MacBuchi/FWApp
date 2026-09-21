/// inventory_providers.dart – Inventurassistent: Session anlegen (mit Soll-
/// Snapshot je Zuweisung), Prüfstatus setzen, Session abschließen.
/// Schichtung: bewusst ohne data/domain-Schicht, direkter DAO-Zugriff —
/// Inventurdaten sind rein lokal und werden nicht synchronisiert
/// (siehe CONTRIBUTING.md „Schichtung je Feature").
library;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

/// Live checks of a session (stream).
final inventoryChecksProvider =
    StreamProvider.family<List<InventoryCheckData>, int>((ref, sessionId) =>
        ref.watch(inventoryDaoProvider).watchChecks(sessionId));

/// Aggregated progress/result for a session.
class InventorySummary {
  final int total;
  final int checked; // status != open
  final int ok;
  final int missing;
  final int damaged;
  final int repair;

  const InventorySummary({
    required this.total,
    required this.checked,
    required this.ok,
    required this.missing,
    required this.damaged,
    required this.repair,
  });

  factory InventorySummary.from(List<InventoryCheckData> checks) {
    var ok = 0, missing = 0, damaged = 0, repair = 0, checked = 0;
    for (final c in checks) {
      if (c.status == InventoryChecks.statusOpen) continue;
      checked++;
      switch (c.status) {
        case InventoryChecks.statusOk:
          ok++;
        case InventoryChecks.statusMissing:
          missing++;
        case InventoryChecks.statusDamaged:
          damaged++;
        case InventoryChecks.statusRepair:
          repair++;
      }
    }
    return InventorySummary(
        total: checks.length,
        checked: checked,
        ok: ok,
        missing: missing,
        damaged: damaged,
        repair: repair);
  }

  bool get complete => total > 0 && checked == total;

  /// Zählt „in Reparatur" bewusst MIT: Der Gerätewart muss auch das
  /// nachhalten, und im Fach liegt das Gerät so wenig wie ein fehlendes.
  bool get hasIssues => missing > 0 || damaged > 0 || repair > 0;

  /// Die Zustände, die im Bericht als Abweichung erscheinen.
  static const abweichendeStatus = {
    InventoryChecks.statusMissing,
    InventoryChecks.statusDamaged,
    InventoryChecks.statusRepair,
  };
}

/// Kopfdaten des Berichts — alles, was nicht in den Prüfzeilen steht.
class InventurBerichtKopf {
  final String fahrzeug;

  /// Der Zeitpunkt, der im Bericht steht: der Abschluss, solange es einen
  /// gibt, sonst der Beginn. Der Bericht lässt sich teilen, BEVOR die
  /// Inventur abgeschlossen ist — dann ist das Startdatum die einzige
  /// ehrliche Angabe.
  final DateTime zeitpunkt;

  const InventurBerichtKopf({required this.fahrzeug, required this.zeitpunkt});
}

final inventurBerichtKopfProvider =
    FutureProvider.family<InventurBerichtKopf, int>((ref, sessionId) async {
  final session = await ref.watch(inventoryDaoProvider).getSession(sessionId);
  if (session == null) {
    return InventurBerichtKopf(fahrzeug: '', zeitpunkt: DateTime.now());
  }
  final fahrzeug =
      await ref.watch(vehicleDetailProvider(session.vehicleId).future);
  return InventurBerichtKopf(
    fahrzeug: fahrzeug?.name ?? 'Fahrzeug ${session.vehicleId}',
    zeitpunkt: session.finishedAt ?? session.startedAt,
  );
});

class InventoryService {
  final AppDatabase db;
  InventoryService(this.db);

  /// Resumes an open session for [vehicleId] or creates a new one, snapshotting
  /// the current Soll-Beladung (label, equipment name, target quantity).
  Future<int> startOrResume(int vehicleId) async {
    final open = await db.inventoryDao.getOpenSession(vehicleId);
    if (open != null) return open.id;

    final sessionId = await db.inventoryDao.createSession(
        InventorySessionsCompanion.insert(vehicleId: vehicleId));

    final compartments = await db.compartmentDao.getByVehicle(vehicleId);
    final checks = <InventoryChecksCompanion>[];
    for (final c in compartments) {
      final assignments = await db.assignmentDao.getByCompartment(c.id);
      for (final a in assignments) {
        final eq = await db.equipmentDao.getById(a.equipmentId);
        checks.add(InventoryChecksCompanion.insert(
          sessionId: sessionId,
          equipmentId: Value(a.equipmentId),
          compartmentId: Value(c.id),
          equipmentName: eq?.name ?? 'Gerät ${a.equipmentId}',
          compartmentLabel: c.label,
          targetQuantity: Value(a.quantity),
        ));
      }
    }
    if (checks.isNotEmpty) await db.inventoryDao.insertChecks(checks);
    return sessionId;
  }

  Future<void> setStatus(int checkId, String status,
          {int? actualQuantity, String? note}) =>
      db.inventoryDao.updateCheck(
        checkId,
        InventoryChecksCompanion(
          status: Value(status),
          actualQuantity: Value(actualQuantity),
          note: note == null ? const Value.absent() : Value(note),
        ),
      );

  Future<void> finish(int sessionId, {String doneBy = ''}) =>
      db.inventoryDao.finishSession(sessionId, doneBy: doneBy);

  Future<void> discard(int sessionId) =>
      db.inventoryDao.deleteSession(sessionId);
}

final inventoryServiceProvider = Provider<InventoryService>(
    (ref) => InventoryService(ref.watch(appDatabaseProvider)));
