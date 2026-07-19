/// sync_service.dart – Snapshot sync between the local Drift DB and the
/// central Supabase dataset. Single-writer model: members pull the published
/// snapshot; the admin publishes the full local dataset via the
/// publish_snapshot RPC (optimistic version check, no conflict resolution).
library;
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drift tables mirrored to Supabase (SQL names, parent→child order).
const kSyncedTables = [
  'vehicles',
  'equipment_items',
  'compartments',
  'equipment_assignments',
  'equipment_instances',
  'inspection_schedules',
  'inspection_log',
];

class SyncService {
  final AppDatabase db;
  final SupabaseClient client;

  bool _suppressDirty = false;
  StreamSubscription<Set<TableUpdate>>? _dirtySub;

  SyncService(this.db, this.client);

  // ── SyncMeta helpers ──

  Future<SyncMetaData> getMeta() async {
    final row = await (db.select(db.syncMeta)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row != null) return row;
    await db.into(db.syncMeta).insert(const SyncMetaCompanion());
    return (db.select(db.syncMeta)..where((t) => t.id.equals(1))).getSingle();
  }

  Stream<SyncMetaData?> watchMeta() => (db.select(db.syncMeta)
        ..where((t) => t.id.equals(1)))
      .watchSingleOrNull();

  Future<void> _setMeta({int? version, bool? dirty}) async {
    await getMeta(); // ensure row exists
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(
      lastPulledVersion: version != null ? Value(version) : const Value.absent(),
      lastPulledAt:
          version != null ? Value(DateTime.now()) : const Value.absent(),
      localDirty: dirty != null ? Value(dirty) : const Value.absent(),
    ));
  }

  /// Marks the local dataset dirty whenever a synced table changes outside
  /// of a sync operation (drives the "unveröffentlichte Änderungen" hint).
  void startDirtyTracking() {
    _dirtySub ??=
        db.tableUpdates(TableUpdateQuery.any()).listen((updates) async {
      if (_suppressDirty) return;
      if (updates.any((u) => kSyncedTables.contains(u.table))) {
        _suppressDirty = true; // _setMeta itself must not re-trigger
        try {
          await _setMeta(dirty: true);
        } finally {
          _suppressDirty = false;
        }
      }
    });
  }

  void dispose() {
    _dirtySub?.cancel();
    _dirtySub = null;
  }

  // ── Pull (members and admins) ──

  /// Fetches the central snapshot if its version is newer than the local one
  /// (always when [force]). Returns the new version, or null if unchanged.
  Future<int?> pullIfNewer({bool force = false}) async {
    final meta = await getMeta();
    final remote =
        await client.from('dataset_meta').select('version').single();
    final remoteVersion = (remote['version'] as num).toInt();
    if (!force && remoteVersion <= meta.lastPulledVersion) return null;

    final data = <String, List<Map<String, dynamic>>>{};
    for (final table in kSyncedTables) {
      data[table] =
          List<Map<String, dynamic>>.from(await client.from(table).select());
    }

    _suppressDirty = true;
    try {
      await db.transaction(() async {
        await _applySnapshot(data);
        await _setMeta(version: remoteVersion, dirty: false);
      });
    } finally {
      _suppressDirty = false;
    }
    appLog.i('Pulled dataset version $remoteVersion '
        '(${data.values.fold<int>(0, (n, rows) => n + rows.length)} rows).');
    return remoteVersion;
  }

  /// Upserts incoming rows and deletes local rows that are no longer in the
  /// snapshot. Upserting (instead of wipe+insert) keeps row identities stable
  /// so local-only references (QuizResults.vehicleId) survive the pull.
  Future<void> _applySnapshot(Map<String, List<Map<String, dynamic>>> data) async {
    // Delete stale rows children-first.
    for (final table in kSyncedTables.reversed) {
      final ids = data[table]!.map((r) => (r['id'] as num).toInt()).toList();
      switch (table) {
        case 'inspection_log':
          await (db.delete(db.inspectionLog)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'inspection_schedules':
          await (db.delete(db.inspectionSchedules)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'equipment_instances':
          await (db.delete(db.equipmentInstances)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'equipment_assignments':
          await (db.delete(db.equipmentAssignments)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'compartments':
          await (db.delete(db.compartments)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'equipment_items':
          await (db.delete(db.equipmentItems)
                ..where((t) => t.id.isNotIn(ids)))
              .go();
        case 'vehicles':
          await (db.delete(db.vehicles)..where((t) => t.id.isNotIn(ids))).go();
      }
    }

    // Upsert incoming rows parents-first.
    for (final r in data['vehicles']!) {
      await db.into(db.vehicles).insertOnConflictUpdate(VehiclesCompanion(
            id: Value(_int(r['id'])),
            name: Value(r['name'] as String),
            type: Value(r['type'] as String),
            licensePlate: Value(r['license_plate'] as String?),
            imagePath: Value(r['image_path'] as String?),
            createdAt: Value(_dt(r['created_at'])),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['equipment_items']!) {
      await db
          .into(db.equipmentItems)
          .insertOnConflictUpdate(EquipmentItemsCompanion(
            id: Value(_int(r['id'])),
            name: Value(r['name'] as String),
            shortName: Value(r['short_name'] as String?),
            equipmentFunctionsJson:
                Value(r['equipment_functions_json'] as String),
            deploymentScenariosJson:
                Value(r['deployment_scenarios_json'] as String),
            description: Value(r['description'] as String),
            imagePath: Value(r['image_path'] as String?),
            trainingUrl: Value(r['training_url'] as String?),
            libraryEquipmentId: Value(r['library_equipment_id'] as String?),
            isCustom: Value(r['is_custom'] as bool),
            extraAttributesJson: Value(r['extra_attributes_json'] as String),
            trainingQuestionsJson:
                Value(r['training_questions_json'] as String),
            typicalUseJson: Value(r['typical_use_json'] as String),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['compartments']!) {
      await db
          .into(db.compartments)
          .insertOnConflictUpdate(CompartmentsCompanion(
            id: Value(_int(r['id'])),
            vehicleId: Value(_int(r['vehicle_id'])),
            label: Value(r['label'] as String),
            position: Value(_int(r['position'])),
            gridRow: Value(_intOrNull(r['grid_row'])),
            gridCol: Value(_intOrNull(r['grid_col'])),
            gridColSpan: Value(_int(r['grid_col_span'])),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['equipment_assignments']!) {
      await db
          .into(db.equipmentAssignments)
          .insertOnConflictUpdate(EquipmentAssignmentsCompanion(
            id: Value(_int(r['id'])),
            compartmentId: Value(_int(r['compartment_id'])),
            equipmentId: Value(_int(r['equipment_id'])),
            quantity: Value(_int(r['quantity'])),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['equipment_instances']!) {
      await db
          .into(db.equipmentInstances)
          .insertOnConflictUpdate(EquipmentInstancesCompanion(
            id: Value(_int(r['id'])),
            equipmentId: Value(_int(r['equipment_id'])),
            vehicleId: Value(_intOrNull(r['vehicle_id'])),
            compartmentId: Value(_intOrNull(r['compartment_id'])),
            identifier: Value(r['identifier'] as String?),
            notes: Value(r['notes'] as String),
            isActive: Value(r['is_active'] as bool),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['inspection_schedules']!) {
      await db
          .into(db.inspectionSchedules)
          .insertOnConflictUpdate(InspectionSchedulesCompanion(
            id: Value(_int(r['id'])),
            instanceId: Value(_int(r['instance_id'])),
            kind: Value(r['kind'] as String),
            title: Value(r['title'] as String),
            intervalMonths: Value(_intOrNull(r['interval_months'])),
            lastDoneAt: Value(_dtOrNull(r['last_done_at'])),
            dueAt: Value(_dt(r['due_at'])),
            notes: Value(r['notes'] as String),
            updatedAt: Value(_dt(r['updated_at'])),
          ));
    }
    for (final r in data['inspection_log']!) {
      await db
          .into(db.inspectionLog)
          .insertOnConflictUpdate(InspectionLogCompanion(
            id: Value(_int(r['id'])),
            scheduleId: Value(_int(r['schedule_id'])),
            doneAt: Value(_dt(r['done_at'])),
            doneBy: Value(r['done_by'] as String),
            note: Value(r['note'] as String),
          ));
    }
  }

  // ── Publish (admin only, enforced again server-side) ──

  /// Uploads the full local dataset as the new central snapshot.
  /// Fails with a version conflict if someone else published since the last
  /// pull — pull first, then republish.
  Future<int> publish() async {
    final meta = await getMeta();
    final payload = await _buildPayload();
    final result = await client.rpc('publish_snapshot', params: {
      'expected_version': meta.lastPulledVersion,
      'payload': payload,
    });
    final newVersion = (result as num).toInt();
    _suppressDirty = true;
    try {
      await _setMeta(version: newVersion, dirty: false);
    } finally {
      _suppressDirty = false;
    }
    appLog.i('Published dataset version $newVersion.');
    return newVersion;
  }

  Future<Map<String, dynamic>> _buildPayload() async {
    final vehicles = await db.vehicleDao.getAll();
    final equipment = await db.equipmentDao.getAll();
    final compartments = await db.select(db.compartments).get();
    final assignments = await db.select(db.equipmentAssignments).get();
    final instances = await db.select(db.equipmentInstances).get();
    final schedules = await db.select(db.inspectionSchedules).get();
    final log = await db.select(db.inspectionLog).get();

    return {
      'vehicles': [
        for (final v in vehicles)
          {
            'id': v.id,
            'name': v.name,
            'type': v.type,
            'license_plate': v.licensePlate,
            'image_path': v.imagePath,
            'created_at': _ts(v.createdAt),
            'updated_at': _ts(v.updatedAt),
          }
      ],
      'equipment_items': [
        for (final e in equipment)
          {
            'id': e.id,
            'name': e.name,
            'short_name': e.shortName,
            'equipment_functions_json': e.equipmentFunctionsJson,
            'deployment_scenarios_json': e.deploymentScenariosJson,
            'description': e.description,
            'image_path': e.imagePath,
            'training_url': e.trainingUrl,
            'library_equipment_id': e.libraryEquipmentId,
            'is_custom': e.isCustom,
            'extra_attributes_json': e.extraAttributesJson,
            'training_questions_json': e.trainingQuestionsJson,
            'typical_use_json': e.typicalUseJson,
            'updated_at': _ts(e.updatedAt),
          }
      ],
      'compartments': [
        for (final c in compartments)
          {
            'id': c.id,
            'vehicle_id': c.vehicleId,
            'label': c.label,
            'position': c.position,
            'grid_row': c.gridRow,
            'grid_col': c.gridCol,
            'grid_col_span': c.gridColSpan,
            'updated_at': _ts(c.updatedAt),
          }
      ],
      'equipment_assignments': [
        for (final a in assignments)
          {
            'id': a.id,
            'compartment_id': a.compartmentId,
            'equipment_id': a.equipmentId,
            'quantity': a.quantity,
            'updated_at': _ts(a.updatedAt),
          }
      ],
      'equipment_instances': [
        for (final i in instances)
          {
            'id': i.id,
            'equipment_id': i.equipmentId,
            'vehicle_id': i.vehicleId,
            'compartment_id': i.compartmentId,
            'identifier': i.identifier,
            'notes': i.notes,
            'is_active': i.isActive,
            'updated_at': _ts(i.updatedAt),
          }
      ],
      'inspection_schedules': [
        for (final s in schedules)
          {
            'id': s.id,
            'instance_id': s.instanceId,
            'kind': s.kind,
            'title': s.title,
            'interval_months': s.intervalMonths,
            'last_done_at': s.lastDoneAt == null ? null : _ts(s.lastDoneAt!),
            'due_at': _ts(s.dueAt),
            'notes': s.notes,
            'updated_at': _ts(s.updatedAt),
          }
      ],
      'inspection_log': [
        for (final l in log)
          {
            'id': l.id,
            'schedule_id': l.scheduleId,
            'done_at': _ts(l.doneAt),
            'done_by': l.doneBy,
            'note': l.note,
          }
      ],
    };
  }

  // ── Conversion helpers ──

  static int _int(dynamic v) => (v as num).toInt();
  static int? _intOrNull(dynamic v) => v == null ? null : (v as num).toInt();
  static DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
  static DateTime? _dtOrNull(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();
  static String _ts(DateTime d) => d.toUtc().toIso8601String();
}
