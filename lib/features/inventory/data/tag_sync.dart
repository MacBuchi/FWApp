/// tag_sync.dart – Der zeilenweise Abgleich der Geräte-Codes (Issue #177).
///
/// **Wozu.** v1.49/v1.50 konnten Codes vergeben, aufkleben und abscannen —
/// aber alles davon endete in der Datenbank DES GERÄTS. Der Gerätewart klebt
/// die Aufkleber, und beim nächsten Inventurtermin steht jemand anderes mit
/// seinem Handy vor dem Fahrzeug und scannt ins Leere. Erst dieser Abgleich
/// macht aus dem Aufkleber einen Code der Wehr.
///
/// **Warum nicht im Snapshot.** ⚠️ `publish_snapshot` ersetzt die Zeilen der
/// Abteilung. Läge `equipment_tags` darin, löschte ein Alt-Client — der den
/// Schlüssel nicht mitschickt — bei seiner nächsten Veröffentlichung alle
/// Codes der Abteilung; die Aufkleber klebten weiter und zeigten auf nichts.
/// Derselbe eigene Weg wie bei den Unterlagen (#182) und den Gerätetypen
/// (#99), siehe `kSyncedTables` in `sync_service.dart`.
///
/// **Warum der Code der Schlüssel ist.** Auf dem Server heißt der
/// Primärschlüssel `(abteilung_id, code)`, nicht die lokale Drift-ID. Zwei
/// Gerätewarte, die am selben Nachmittag in zwei Geräteräumen Codes
/// vergeben, bekommen von ihrer jeweiligen Datenbank dieselben laufenden
/// Nummern — der zweite überschriebe den ersten, und ein fertig aufgeklebter
/// Aufkleber zeigte plötzlich auf ein anderes Gerät. Der Code dagegen ist
/// genau das, was in der Wirklichkeit eindeutig ist.
///
/// **Warum Entfernen ein Soft-Delete ist.** Ein Zug kann eine harte Löschung
/// nicht sehen: Die Zeile käme schlicht nicht mehr, und das ist von „noch
/// nie gesehen" nicht zu unterscheiden. Ohne Grabstein käme jeder entfernte
/// Code beim nächsten Schieben eines anderen Geräts wieder hoch. Dieselbe
/// Lösung wie bei `quiz_questions` (#174).
///
/// **Reihenfolge: erst schieben, dann ziehen.** Andersherum überschriebe der
/// Zug einen Code, der hier gerade erst vergeben wurde, bevor er oben
/// ankommt. Dasselbe Paar wie beim Wissen, aus demselben Grund.
library;

import 'package:drift/drift.dart' show Value;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TagSync {
  final AppDatabase db;
  final SupabaseClient? client;

  const TagSync({required this.db, this.client});

  /// Schiebt, was hier entstanden oder entfernt wurde.
  ///
  /// Gibt zurück, wie viele Zeilen oben angekommen sind.
  Future<int> schiebe(String abteilungId) async {
    final c = client;
    final nutzer = c?.auth.currentUser;
    if (c == null || nutzer == null) return 0;

    var geschoben = 0;
    for (final t in await db.tagDao.offeneTags()) {
      try {
        await c.from('equipment_tags').upsert({
          'abteilung_id': abteilungId,
          'code': t.code,
          'instance_id': t.instanceId,
          'kind': t.kind,
          'self_issued': t.selfIssued,
          'created_at': t.createdAt.toUtc().toIso8601String(),
          'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': nutzer.id,
        });
      } catch (e) {
        // Kein Rethrow: Der Code steht lokal und bleibt `dirty` — der
        // nächste Abgleich reicht ihn nach. Ein offline vergebener
        // Aufkleber darf nicht den ganzen Zug scheitern lassen.
        appLog.w('Code ${t.code} nicht hochladbar', error: e);
        continue;
      }

      if (t.deletedAt != null) {
        // Der Grabstein hat seinen Zweck erfüllt: Ab jetzt weiß der Server
        // Bescheid, und der Code ist hier wieder frei.
        await db.tagDao.deleteTag(t.id);
      } else {
        await db.tagDao
            .aendere(t.id, const EquipmentTagsCompanion(dirty: Value(false)));
      }
      geschoben++;
    }
    return geschoben;
  }

  /// Holt die Codes der Abteilung in den lokalen Bestand.
  ///
  /// Gibt zurück, wie viele Zeilen übernommen wurden — Grabsteine und
  /// übersprungene zählen nicht mit.
  Future<int> ziehe(String abteilungId) async {
    final c = client;
    if (c == null) return 0;

    final zeilen = List<Map<String, dynamic>>.from(
        await c.from('equipment_tags').select().eq('abteilung_id', abteilungId));

    var gezogen = 0;
    for (final r in zeilen) {
      final code = r['code'] as String;
      final lokal = await db.tagDao.findByCodeAuchEntfernt(code);

      // ⚠️ Was hier noch aufs Hochladen wartet, NICHT überschreiben — sonst
      // verliert der Gerätewart den Code, den er gerade vergeben hat, sobald
      // er zwischendurch aktualisiert. Das gilt auch für einen Grabstein:
      // Wer den Aufkleber abgezogen hat, soll ihn nicht zurückbekommen.
      if (lokal != null && lokal.dirty) continue;

      if (r['deleted_at'] != null) {
        if (lokal != null) await db.tagDao.deleteTag(lokal.id);
        continue;
      }

      final instanceId = (r['instance_id'] as num).toInt();
      // ⚠️ Die Einheit muss hier schon liegen — die Spalte trägt einen
      // Fremdschlüssel mit `cascade`, ein Insert ins Leere bricht ab. Beim
      // ersten Start kommt dieser Zug NACH dem Snapshot, trotzdem kann eine
      // Einheit fehlen: Wer den Code vergeben hat, muss danach noch
      // veröffentlicht haben. Dann wartet der Code auf den nächsten Zug,
      // statt den ganzen Abgleich abzubrechen.
      if (await db.tagDao.getInstanceById(instanceId) == null) {
        appLog.d('Code $code wartet auf Einheit $instanceId');
        continue;
      }

      final kind = r['kind'] as String? ?? EquipmentTags.kindQr;
      final selfIssued = r['self_issued'] as bool? ?? false;
      if (lokal == null) {
        await db.tagDao.insertTag(EquipmentTagsCompanion.insert(
          instanceId: instanceId,
          code: code,
          kind: Value(kind),
          selfIssued: Value(selfIssued),
          createdAt: Value(_zeit(r['created_at'])),
          dirty: const Value(false),
        ));
      } else {
        // Derselbe Code an einer anderen Einheit: Der Server hat recht. Er
        // ist die einzige Stelle, die beide Geräte gesehen hat.
        await db.tagDao.aendere(
          lokal.id,
          EquipmentTagsCompanion(
            instanceId: Value(instanceId),
            kind: Value(kind),
            selfIssued: Value(selfIssued),
            dirty: const Value(false),
            deletedAt: const Value(null),
          ),
        );
      }
      gezogen++;
    }
    return gezogen;
  }

  static DateTime _zeit(Object? wert) =>
      DateTime.tryParse(wert as String? ?? '')?.toLocal() ?? DateTime.now();
}
