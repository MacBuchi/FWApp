/// tag_providers.dart – Codes an Geräte-Einheiten: vergeben, verknüpfen,
/// nachschlagen (Issues #177/#179).
///
/// Schichtung: wie beim Inventurassistenten bewusst ohne data/domain-Schicht,
/// direkter DAO-Zugriff (siehe CONTRIBUTING.md „Schichtung je Feature").
///
/// Geschrieben wird immer NUR lokal — auch beim Entfernen. Was davon auf den
/// Server gehört, holt sich `tag_sync.dart` beim nächsten Abgleich anhand von
/// [EquipmentTags.dirty]. Das ist die Zusage für den Geräteraum: Dort ist
/// selten Netz, und ein Aufkleber, der erst mit Verbindung vergeben werden
/// kann, wäre im Einsatzfall wertlos.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';
import 'package:fwapp/features/inventory/data/tag_sync.dart';

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

final tagsDerEinheitProvider = StreamProvider.family<
  List<EquipmentTagData>,
  int
>((ref, instanceId) => ref.watch(tagDaoProvider).watchByInstance(instanceId));

class TagDienst {
  final AppDatabase db;
  TagDienst(this.db);

  /// Ein freier Code, noch ohne Zeile in der Datenbank.
  ///
  /// Für den NFC-Weg (#176): Dort muss der Code **erst auf das Tag**, und
  /// erst wenn das geklappt hat, gehört er an die Einheit. Andersherum
  /// entstünde bei jedem schreibgeschützten Tag eine Karteileiche.
  Future<String> naechsterFreierCode() async =>
      erzeugeTagCode(await db.tagDao.alleCodes());

  /// Vergibt einen eigenen Code und hängt ihn an [instanceId].
  Future<String> vergebeCode(int instanceId) async {
    final code = erzeugeTagCode(await db.tagDao.alleCodes());
    await db.tagDao.insertTag(
      EquipmentTagsCompanion.insert(
        instanceId: instanceId,
        code: code,
        selfIssued: const Value(true),
      ),
    );
    return code;
  }

  /// Übernimmt einen vorhandenen Code für [instanceId].
  ///
  /// [artDesTags] überschreibt die Herkunft, die sonst am Code abgelesen
  /// wird — der NFC-Weg weiß sie besser als der Code selbst (#176).
  /// [selbstVergeben] sagt, ob die App den Code gewürfelt hat; davon hängt
  /// nur die Anzeige ab.
  Future<TagErgebnis> verknuepfe(
    int instanceId,
    String roh, {
    String? artDesTags,
    bool selbstVergeben = false,
  }) async {
    final code = normalisiereTagCode(roh);
    if (code == null) return const TagLeer();

    final art = Value(
      artDesTags ??
          (istEigenerCode(code)
              ? EquipmentTags.kindQr
              : EquipmentTags.kindBarcode),
    );

    // Auch Grabsteine: Die Spalte ist `unique`, und ein entfernter Code, der
    // noch auf sein Hochladen wartet, belegt sie weiter.
    final vorhanden = await db.tagDao.findByCodeAuchEntfernt(code);
    if (vorhanden != null && vorhanden.deletedAt == null) {
      // Auch wenn er an DERSELBEN Einheit hängt: Ein zweiter Eintrag wäre
      // sinnlos, und „klebt schon auf X" ist die ehrlichere Auskunft als
      // ein stilles Nichts.
      final treffer = await schlageNach(code);
      return TagSchonVergeben(code, treffer?.geraetename ?? 'einem Gerät');
    }
    if (vorhanden != null) {
      // Derselbe Aufkleber wird neu verklebt, bevor das Entfernen oben
      // ankam — im Geräteraum der Normalfall, nicht die Ausnahme. Den
      // Grabstein wiederbeleben statt einzufügen: Ein zweiter Eintrag bräche
      // an `unique` ab, und ein dazwischen laufender Abgleich schöbe sonst
      // erst die Löschung und dann den Neuzugang.
      await db.tagDao.aendere(
        vorhanden.id,
        EquipmentTagsCompanion(
          instanceId: Value(instanceId),
          kind: art,
          selfIssued: Value(selbstVergeben),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );
      return TagVerknuepft(code);
    }

    await db.tagDao.insertTag(
      EquipmentTagsCompanion.insert(
        instanceId: instanceId,
        code: code,
        kind: art,
        selfIssued: Value(selbstVergeben),
      ),
    );
    return TagVerknuepft(code);
  }

  /// Nimmt den Code von der Einheit.
  ///
  /// **Zwei Wege, je nachdem ob der Code den Server je erreicht hat.** Ein
  /// Code, der noch `dirty` ist, war nie oben — der fällt hier weg und
  /// hinterlässt nichts. Ein bereits geschobener wird zum Grabstein: Ohne
  /// ihn käme er beim nächsten Zug von einem anderen Gerät zurück, weil ein
  /// Zug eine harte Löschung nicht sehen kann (`tag_sync.dart`).
  Future<void> entferne(EquipmentTagData tag) async {
    if (tag.dirty) {
      await db.tagDao.deleteTag(tag.id);
      return;
    }
    await db.tagDao.aendere(
      tag.id,
      EquipmentTagsCompanion(
        deletedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

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

final tagDienstProvider = Provider<TagDienst>(
  (ref) => TagDienst(ref.watch(appDatabaseProvider)),
);

final tagSyncProvider = Provider<TagSync>(
  (ref) => TagSync(
    db: ref.watch(appDatabaseProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);
