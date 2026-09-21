/// tag_providers.dart – Codes an Geräte-Einheiten: vergeben, verknüpfen,
/// nachschlagen (Issues #177/#179).
///
/// Schichtung: wie beim Inventurassistenten bewusst ohne data/domain-Schicht,
/// direkter DAO-Zugriff (siehe CONTRIBUTING.md „Schichtung je Feature"). Die
/// Tags hängen an der lokalen Datenbank; der Sync kommt in einem eigenen
/// Schritt, weil eine neue Tabelle im Snapshot einen Alt-Client dazu bringen
/// würde, sie bei seiner nächsten Veröffentlichung zu leeren
/// (`sync_service.dart`, Kopfkommentar).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';

/// Was beim Verknüpfen herauskam.
sealed class TagErgebnis {
  const TagErgebnis();
}

/// Der Code hängt jetzt an der Einheit.
class TagVerknuepft extends TagErgebnis {
  final String code;
  const TagVerknuepft(this.code);
}

/// Es stand nichts Verwertbares da (leer, nur Leerraum).
class TagLeer extends TagErgebnis {
  const TagLeer();
}

/// Der Code klebt schon woanders — mit Angabe, wo.
///
/// Das ist der Grund, warum vor dem Einfügen nachgesehen wird, statt sich
/// auf `unique` zu verlassen: Ein Constraint-Fehler sagt nicht, an welchem
/// Gerät der Code schon hängt.
class TagSchonVergeben extends TagErgebnis {
  final String code;
  final String geraet;
  const TagSchonVergeben(this.code, this.geraet);
}

/// Wohin ein gelesener Code zeigt.
class TagTreffer {
  final EquipmentTagData tag;
  final EquipmentInstanceData einheit;
  final String geraetename;
  const TagTreffer(this.tag, this.einheit, this.geraetename);
}

final tagsDerEinheitProvider =
    StreamProvider.family<List<EquipmentTagData>, int>((ref, instanceId) =>
        ref.watch(tagDaoProvider).watchByInstance(instanceId));

class TagDienst {
  final AppDatabase db;
  TagDienst(this.db);

  /// Vergibt einen eigenen Code und hängt ihn an [instanceId].
  Future<String> vergebeCode(int instanceId) async {
    final code = erzeugeTagCode(await db.tagDao.alleCodes());
    await db.tagDao.insertTag(EquipmentTagsCompanion.insert(
      instanceId: instanceId,
      code: code,
      selfIssued: const Value(true),
    ));
    return code;
  }

  /// Übernimmt einen vorhandenen Code für [instanceId].
  Future<TagErgebnis> verknuepfe(int instanceId, String roh) async {
    final code = normalisiereTagCode(roh);
    if (code == null) return const TagLeer();

    final vorhanden = await db.tagDao.findByCode(code);
    if (vorhanden != null) {
      // Auch wenn er an DERSELBEN Einheit hängt: Ein zweiter Eintrag wäre
      // sinnlos, und „klebt schon auf X" ist die ehrlichere Auskunft als
      // ein stilles Nichts.
      final treffer = await schlageNach(code);
      return TagSchonVergeben(code, treffer?.geraetename ?? 'einem Gerät');
    }

    await db.tagDao.insertTag(EquipmentTagsCompanion.insert(
      instanceId: instanceId,
      code: code,
      kind: Value(istEigenerCode(code)
          ? EquipmentTags.kindQr
          : EquipmentTags.kindBarcode),
    ));
    return TagVerknuepft(code);
  }

  Future<void> entferne(int tagId) => db.tagDao.deleteTag(tagId);

  /// Schlägt einen gelesenen Code nach — normalisiert dabei selbst, damit
  /// jeder Aufrufer (Tastatur, Scanner) denselben Weg nimmt.
  Future<TagTreffer?> schlageNach(String roh) async {
    final code = normalisiereTagCode(roh);
    if (code == null) return null;
    final tag = await db.tagDao.findByCode(code);
    if (tag == null) return null;
    final einheit = await db.tagDao.getInstanceById(tag.instanceId);
    if (einheit == null) return null;
    final geraet = await db.equipmentDao.getById(einheit.equipmentId);
    return TagTreffer(
      tag,
      einheit,
      geraet?.name ?? 'Gerät ${einheit.equipmentId}',
    );
  }
}

final tagDienstProvider =
    Provider<TagDienst>((ref) => TagDienst(ref.watch(appDatabaseProvider)));
