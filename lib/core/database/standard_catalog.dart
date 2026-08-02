/// standard_catalog.dart – Zugriff auf den gebündelten Standard-Katalog
/// (assets/equipment_library/catalog/standard_catalog.json).
///
/// Warum eine eigene Klasse: Der Library-Seeder überspringt auf Geräten, die
/// schon einmal den zentralen Datenbestand gezogen haben, ALLES — auch den
/// Katalog, denn der Pull ersetzt den lokalen Bestand vollständig und gilt
/// als Wahrheit. Eine Fahrzeug-Vorlage mit Normbeladung fand dann kein
/// einziges Gerät wieder und legte still ein leeres Fahrzeug an (Issue #86).
/// Der Katalog muss deshalb gezielt, Position für Position, nachlegbar sein —
/// nicht nur einmal beim ersten Start.
library;
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/image_utils.dart';

class StandardCatalog {
  final Map<String, Map<String, dynamic>> _byId;

  StandardCatalog._(this._byId);

  /// Leerer Katalog — für Tests und als Rückfall, wenn das Asset fehlt.
  StandardCatalog.empty() : _byId = const {};

  /// Alle Katalog-IDs in Dateireihenfolge.
  Iterable<String> get ids => _byId.keys;

  bool contains(String libraryId) => _byId.containsKey(libraryId);

  /// Katalog-ID zu einem frei getippten Gerätenamen — oder null.
  ///
  /// Bewusst nur exakte Treffer über Name, Kurzname und Aliasse (normalisiert
  /// wie im Import-Matcher): Das Ergebnis wählt unbeaufsichtigt ein Symbolbild
  /// aus, und ein falsches Bild wiegt schwerer als gar keins. Fuzzy-Raten
  /// bleibt dem Import-Assistenten vorbehalten, wo ein Mensch bestätigt.
  String? idFuerName(String name) => _nameIndex[_norm(name)];

  late final Map<String, String> _nameIndex = (() {
    final index = <String, String>{};
    void merke(String? text, String id) {
      final n = _norm(text ?? '');
      if (n.isNotEmpty) index.putIfAbsent(n, () => id);
    }

    for (final entry in _byId.entries) {
      merke(entry.value['name'] as String?, entry.key);
      merke(entry.value['short_name'] as String?, entry.key);
      for (final alias in (entry.value['aliases'] as List?) ?? const []) {
        merke(alias as String?, entry.key);
      }
    }
    return index;
  })();

  /// Spiegelt EquipmentMatcher.normalize — hierher kopiert statt importiert,
  /// weil core/ nicht in features/ greifen darf.
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  /// Lädt den gebündelten Katalog. Ein fehlendes oder unlesbares Asset ist
  /// ein Build-Fehler und landet im Log — die Aufrufer bekommen trotzdem
  /// einen (leeren) Katalog und können weiterarbeiten.
  static Future<StandardCatalog> load() async {
    try {
      final raw = jsonDecode(await rootBundle
          .loadString('assets/equipment_library/catalog/standard_catalog.json'));
      final items = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      return StandardCatalog._({
        for (final item in items.cast<Map<String, dynamic>>())
          item['id'] as String: item,
      });
    } catch (e, s) {
      appLog.w('Standard-Katalog nicht lesbar — Vorlagen und Seed bleiben '
          'ohne Normbeladung', error: e, stackTrace: s);
      return StandardCatalog.empty();
    }
  }

  /// Legt das Katalog-Gerät [libraryId] in der Datenbank an und liefert die
  /// Zeilen-ID — oder null, wenn die ID nicht im Katalog steht. Prüft NICHT,
  /// ob es das Gerät schon gibt; das ist Sache des Aufrufers
  /// (`getByLibraryId`), damit kein Katalog-Eintrag doppelt entsteht.
  ///
  /// Jeder Eintrag startet mit seinem Piktogramm aus der Bildbibliothek
  /// (erkennbar am Asset-Pfad, siehe isPictogramPath); echte Fotos ersetzen
  /// es später über den Kamera-Workflow.
  Future<int?> createEquipment(AppDatabase db, String libraryId) async {
    final item = _byId[libraryId];
    if (item == null) return null;
    return db.equipmentDao.insertEquipment(EquipmentItemsCompanion.insert(
      name: item['name'] as String,
      shortName: Value(item['short_name'] as String?),
      libraryEquipmentId: Value(libraryId),
      isCustom: const Value(false),
      imagePath: Value(pictogramPath(libraryId)),
      equipmentFunctionsJson: Value(jsonEncode(
          ((item['equipment_functions'] as List?)?.cast<String>()) ?? [])),
      description: Value((item['description'] as String?) ?? ''),
      typicalUseJson: Value(jsonEncode(
          ((item['typical_use'] as List?)?.cast<String>()) ?? [])),
      trainingQuestionsJson: Value(jsonEncode(
          ((item['training_questions'] as List?)?.cast<String>()) ?? [])),
    ));
  }
}
