/// equipment_type_sync.dart – Der zeilenweise Sync der Gerätetypen
/// (Nutzerkonzept Stufe ②, Issue #99).
///
/// **Warum nicht im Snapshot.** Der Bestands-Sync veröffentlicht die ganze
/// Abteilung auf einmal und ist damit Single-Writer. Die Gerätetypen gehören
/// aber der GESAMTWEHR — zwei Gerätewarte, die veröffentlichen, würden sich
/// gegenseitig überschreiben. Deshalb hier ein eigener Weg:
///
/// - **Ziehen** holt nur, was sich seit dem letzten Fenster geändert hat
///   (`updated_at > lastTypePulledAt`), nicht den ganzen Bestand.
/// - **Schieben** geht Zeile für Zeile über `push_equipment_types`; der
///   Server entscheidet je Zeile, ob die Änderung neuer ist.
///
/// **Unsichtbar, wo es keine Gesamtwehr gibt.** Lokalmodus, Alt-Server und
/// Abteilungen ohne Gesamtwehr liefern `null` und jeder Aufruf wird zum
/// No-op — die App läuft dort unverändert auf dem Snapshot-Weg weiter.
///
/// **Die Erstverbindung ist der heikle Teil.** Lokal liegen schon 110
/// Katalog-Geräte aus dem Seeder. Ohne Zuordnung würde der erste Zug sie
/// alle ein zweites Mal anlegen. Deshalb hängt sich ein gezogener Typ an ein
/// vorhandenes, noch unverbundenes Gerät an — erst über die Katalog-ID, dann
/// über den normalisierten Namen, also genau in der Reihenfolge, die der
/// Server benutzt.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/equipment_naming.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EquipmentTypeSync {
  final AppDatabase db;
  final SupabaseClient client;

  /// Angezeigte Abteilung (wie bei [SyncService]); `null` = die eigene.
  final String? abteilungOverride;

  String? _gesamtwehrId;
  bool _ohneGesamtwehr = false;

  EquipmentTypeSync(this.db, this.client, {this.abteilungOverride});

  /// Gesamtwehr der angezeigten Abteilung, einmal je Sitzung aufgelöst.
  /// `null` heißt: kein geteilter Typ-Bestand, alle Aufrufe sind No-ops.
  Future<String?> _gesamtwehr() async {
    if (_ohneGesamtwehr) return null;
    if (_gesamtwehrId != null) return _gesamtwehrId;
    try {
      final abteilung = abteilungOverride ??
          (await client.from('profiles').select('abteilung_id').maybeSingle())
              ?['abteilung_id'] as String?;
      if (abteilung == null) {
        _ohneGesamtwehr = true;
        return null;
      }
      final row = await client
          .from('abteilungen')
          .select('gesamtwehr_id')
          .eq('id', abteilung)
          .maybeSingle();
      _gesamtwehrId = row?['gesamtwehr_id'] as String?;
      if (_gesamtwehrId == null) _ohneGesamtwehr = true;
    } catch (e) {
      appLog.i('Gesamtwehr nicht ermittelbar (Alt-Server?) — Typ-Sync aus',
          error: e);
      _ohneGesamtwehr = true;
    }
    return _gesamtwehrId;
  }

  Future<SyncMetaData> _meta() async {
    final row = await (db.select(db.syncMeta)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row != null) return row;
    await db.into(db.syncMeta).insert(const SyncMetaCompanion());
    return (db.select(db.syncMeta)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Erst schieben, dann ziehen: So sieht der eigene Push sein eigenes
  /// Ergebnis im selben Durchgang bestätigt.
  Future<void> sync() async {
    await push();
    await pull();
  }

  // ── Ziehen ──────────────────────────────────────────────────────────────

  /// Holt alle seit dem letzten Fenster geänderten Typen. [force] zieht
  /// alles — nötig nach einem Abteilungswechsel, weil die lokale Datei der
  /// neuen Sicht ihr eigenes Fenster hat.
  ///
  /// Liefert die Zahl der verarbeiteten Typen.
  Future<int> pull({bool force = false}) async {
    final gw = await _gesamtwehr();
    if (gw == null) return 0;

    final meta = await _meta();
    final seit = force ? null : meta.lastTypeCursor;
    try {
      var query = client.from('equipment_types').select().eq(
            'gesamtwehr_id',
            gw,
          );
      if (seit != null) query = query.gt('updated_at', seit);
      final rows = List<Map<String, dynamic>>.from(
          await query.order('updated_at'));
      if (rows.isEmpty) return 0;

      // Die noch unverbundenen Geräte EINMAL laden: Der Abgleich läuft über
      // den normalisierten Namen, den SQLite nicht kennt.
      final offen = await (db.select(db.equipmentItems)
            ..where((t) => t.remoteTypeId.isNull()))
          .get();
      final nachKatalogId = <String, EquipmentItemData>{};
      final nachName = <String, EquipmentItemData>{};
      for (final e in offen) {
        if (e.libraryEquipmentId != null) {
          nachKatalogId.putIfAbsent(e.libraryEquipmentId!, () => e);
        }
        nachName.putIfAbsent(normalizeEquipmentName(e.name), () => e);
      }

      // Der Cursor ist der Zeitstempel des Servers, wortgleich übernommen.
      // Die Abfrage ist nach `updated_at` sortiert, die letzte Zeile trägt
      // ihn also. Selbst umrechnen würde ihn auf Sekunden runden und das
      // Fenster bei jedem Lauf dieselbe Zeile erneut holen lassen.
      final cursor = rows.last['updated_at'] as String;
      await db.transaction(() async {
        for (final r in rows) {
          await _anwenden(r, nachKatalogId, nachName);
        }
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
            .write(SyncMetaCompanion(lastTypeCursor: Value(cursor)));
      });
      appLog.i('Typ-Sync: ${rows.length} Gerätetypen gezogen.');
      return rows.length;
    } on PostgrestException catch (e) {
      // Server ohne Stufe-②-Migration: Die App darf dem Rollout vorauseilen.
      appLog.i('Typ-Sync nicht möglich (${e.code}) — Server noch ohne Typen.');
      _ohneGesamtwehr = true;
      return 0;
    }
  }

  Future<void> _anwenden(
    Map<String, dynamic> r,
    Map<String, EquipmentItemData> nachKatalogId,
    Map<String, EquipmentItemData> nachName,
  ) async {
    final typId = r['id'] as String;
    final archiviert = r['deleted_at'] != null;

    var lokal = await (db.select(db.equipmentItems)
          ..where((t) => t.remoteTypeId.equals(typId)))
        .getSingleOrNull();

    // Erstverbindung: an ein vorhandenes Gerät anhängen statt verdoppeln.
    if (lokal == null && !archiviert) {
      final katalogId = r['library_equipment_id'] as String?;
      lokal = (katalogId == null ? null : nachKatalogId[katalogId]) ??
          nachName[normalizeEquipmentName(r['name'] as String)];
      if (lokal != null) {
        nachKatalogId.removeWhere((_, v) => v.id == lokal!.id);
        nachName.removeWhere((_, v) => v.id == lokal!.id);
      }
    }

    if (archiviert) {
      // Aus dem Bestand genommen. Lokal verschwindet der Typ nur, wenn ihn
      // hier niemand benutzt — sonst risse es ein Loch in ein Fach oder in
      // die Prüfhistorie eines Exemplars.
      if (lokal != null && !await _wirdBenutzt(lokal.id)) {
        await db.equipmentDao.deleteEquipment(lokal.id);
      }
      return;
    }

    final inhalt = EquipmentItemsCompanion(
      name: Value(r['name'] as String),
      shortName: Value(r['short_name'] as String?),
      equipmentFunctionsJson: Value(r['equipment_functions_json'] as String),
      deploymentScenariosJson: Value(r['deployment_scenarios_json'] as String),
      description: Value(r['description'] as String),
      imagePath: Value(r['image_path'] as String?),
      trainingUrl: Value(r['training_url'] as String?),
      libraryEquipmentId: Value(r['library_equipment_id'] as String?),
      isCustom: Value(r['is_custom'] as bool),
      extraAttributesJson: Value(r['extra_attributes_json'] as String),
      trainingQuestionsJson: Value(r['training_questions_json'] as String),
      typicalUseJson: Value(r['typical_use_json'] as String),
      updatedAt: Value(DateTime.parse(r['updated_at'] as String).toLocal()),
      remoteTypeId: Value(typId),
      remoteTypeUpdatedAt: Value(r['updated_at'] as String),
      // Was gerade vom Server kam, ist per Definition nicht mehr offen.
      typeDirty: const Value(false),
    );

    if (lokal == null) {
      await db.into(db.equipmentItems).insert(inhalt);
    } else {
      await db.equipmentDao.patchEquipment(lokal.id, inhalt);
    }
  }

  Future<bool> _wirdBenutzt(int equipmentId) async {
    final zuordnung = await (db.select(db.equipmentAssignments)
          ..where((t) => t.equipmentId.equals(equipmentId))
          ..limit(1))
        .getSingleOrNull();
    if (zuordnung != null) return true;
    final exemplar = await (db.select(db.equipmentInstances)
          ..where((t) => t.equipmentId.equals(equipmentId))
          ..limit(1))
        .getSingleOrNull();
    return exemplar != null;
  }

  // ── Schieben ────────────────────────────────────────────────────────────

  /// Schiebt alle lokal geänderten Typen hoch. Das Kennzeichen `typeDirty`
  /// setzt, wer den Typ ändert — hier wird es nur abgeräumt.
  ///
  /// ⚠️ **Wer `typeDirty` setzt, muss `updatedAt` mit hochziehen.** Der
  /// Server vergleicht den mitgeschickten Zeitstempel mit seinem eigenen und
  /// verwirft, was älter ist (damit ein lange offline gewesenes Gerät keine
  /// neuere Pflege zurückrollt). Bleibt `updatedAt` auf dem Wert des letzten
  /// Zugs stehen, verwirft der Server die eigene Änderung stillschweigend.
  ///
  /// Liefert die Zahl der geschobenen Typen.
  Future<int> push() async {
    final gw = await _gesamtwehr();
    if (gw == null) return 0;

    final offen = await (db.select(db.equipmentItems)
          ..where((t) => t.typeDirty.equals(true)))
        .get();
    if (offen.isEmpty) return 0;

    try {
      final antwort = await client.rpc('push_equipment_types', params: {
        'gw': gw,
        'aenderungen': [
          for (final e in offen)
            {
              if (e.remoteTypeId != null) 'id': e.remoteTypeId,
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
              // Die Zeilen-Version, wie der Server sie zuletzt meldete —
              // NICHT die lokale Uhr. Der Server lehnt ab, wenn er seither
              // weitergezogen ist. `null` bei einem neuen Typ: Dann gibt es
              // nichts zu überholen.
              'updated_at': e.remoteTypeUpdatedAt,
            },
        ],
      });

      // Der Server antwortet mit den zentral gültigen Zeilen IN DERSELBEN
      // REIHENFOLGE — er baut sie in der Schleife über die Eingabe auf. Nur
      // deshalb darf hier nach Position zugeordnet werden; passt die Länge
      // nicht, wird nichts abgeräumt und der nächste Lauf versucht es neu.
      final zeilen = List<Map<String, dynamic>>.from(antwort as List);
      if (zeilen.length != offen.length) {
        appLog.w('Typ-Sync: Antwort passt nicht zur Anfrage '
            '(${zeilen.length} statt ${offen.length}) — nichts abgeräumt.');
        return 0;
      }

      await db.transaction(() async {
        for (var i = 0; i < offen.length; i++) {
          await db.equipmentDao.patchEquipment(
            offen[i].id,
            EquipmentItemsCompanion(
              remoteTypeId: Value(zeilen[i]['id'] as String),
              remoteTypeUpdatedAt: Value(zeilen[i]['updated_at'] as String),
              // Der Server kann zusammengeführt haben (gleicher Name in einer
              // anderen Abteilung) — dann gilt SEIN Name, nicht der eigene.
              name: Value(zeilen[i]['name'] as String),
              typeDirty: const Value(false),
            ),
          );
        }
      });
      appLog.i('Typ-Sync: ${offen.length} Gerätetypen geschoben.');
      return offen.length;
    } on PostgrestException catch (e) {
      appLog.w('Typ-Sync: Schieben abgelehnt', error: e);
      rethrow;
    }
  }

  /// Wo wird [remoteTypeId] in der Gesamtwehr überall benutzt? Grundlage für
  /// „löschen oder archivieren": Wirklich löschen darf die App nur, was in
  /// KEINER Abteilung zugeordnet ist — und die eigene Sicht zeigt ihr das
  /// nicht.
  Future<int> verwendungInDerGesamtwehr(String remoteTypeId) async {
    final rows = List<Map<String, dynamic>>.from(await client
        .rpc('equipment_type_verwendung', params: {'ziel': remoteTypeId}));
    return rows.fold<int>(
        0,
        (n, r) =>
            n +
            (r['zuordnungen'] as num).toInt() +
            (r['exemplare'] as num).toInt());
  }
}
