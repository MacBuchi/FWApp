/// image_library_providers.dart – Die Bildbibliothek: pro Katalog-Gerät ein
/// Symbolbild (Piktogramm) plus Suchbegriffe (Name, Kurzname, Aliasse).
/// Grundlage für den Bibliotheks-Browser und den Bildwähler.
library;
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart'
    show EquipmentMatcher;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_library_providers.g.dart';

class ImageLibraryEntry {
  final String id;
  final String name;
  final String? shortName;
  final String assetPath;

  /// UPPER_SNAKE-Funktionskategorien (für Filter/Anzeige).
  final List<String> functions;

  /// Normalisierte Suchbegriffe: Name, Kurzname und alle Aliasse.
  final List<String> keywords;

  const ImageLibraryEntry({
    required this.id,
    required this.name,
    required this.shortName,
    required this.assetPath,
    required this.functions,
    required this.keywords,
  });
}

/// Lädt die Bibliothek einmalig aus Katalog + aliases.json.
@Riverpod(keepAlive: true)
Future<List<ImageLibraryEntry>> imageLibrary(Ref ref) async {
  final catalogRaw = await rootBundle
      .loadString('assets/equipment_library/catalog/standard_catalog.json');
  final items =
      ((jsonDecode(catalogRaw) as Map<String, dynamic>)['items'] as List)
          .cast<Map<String, dynamic>>();

  var bundledAliases = <String, List<String>>{};
  try {
    final aliasesRaw = await rootBundle
        .loadString('assets/equipment_library/aliases.json');
    final decoded = jsonDecode(aliasesRaw) as Map<String, dynamic>;
    final map = (decoded['aliases'] ?? decoded) as Map<String, dynamic>;
    bundledAliases = map.map((k, v) =>
        MapEntry(k, (v as List).map((e) => e.toString()).toList()));
  } catch (_) {
    // Ohne aliases.json funktioniert die Suche über Name/Kurzname weiter.
  }

  return [
    for (final item in items)
      ImageLibraryEntry(
        id: item['id'] as String,
        name: item['name'] as String,
        shortName: item['short_name'] as String?,
        assetPath: pictogramPath(item['id'] as String),
        functions:
            ((item['equipment_functions'] as List?)?.cast<String>()) ?? [],
        keywords: {
          EquipmentMatcher.normalize(item['name'] as String),
          if (item['short_name'] != null)
            EquipmentMatcher.normalize(item['short_name'] as String),
          ...((item['aliases'] as List?) ?? [])
              .map((a) => EquipmentMatcher.normalize(a.toString())),
          ...(bundledAliases[item['id']] ?? [])
              .map(EquipmentMatcher.normalize),
        }.where((k) => k.isNotEmpty).toList(),
      )
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// Sucht intuitiv: Wortanfänge schlagen Teiltreffer, Name schlägt Alias.
/// Leere Suche liefert alles (alphabetisch).
List<ImageLibraryEntry> searchImageLibrary(
    List<ImageLibraryEntry> entries, String query) {
  final q = EquipmentMatcher.normalize(query);
  if (q.isEmpty) return entries;

  int? scoreOf(ImageLibraryEntry e) {
    final name = e.keywords.isEmpty ? '' : e.keywords.first;
    int? best;
    void consider(int s) => best = (best == null || s < best!) ? s : best;
    if (name.startsWith(q)) consider(0);
    for (final kw in e.keywords) {
      if (kw == q) consider(0);
      if (kw.startsWith(q)) consider(1);
      if (kw.split(' ').any((w) => w.startsWith(q))) consider(2);
      if (kw.contains(q)) consider(3);
    }
    return best;
  }

  final scored = <(int, ImageLibraryEntry)>[
    for (final e in entries)
      if (scoreOf(e) case final s?) (s, e)
  ];
  scored.sort((a, b) {
    final byScore = a.$1.compareTo(b.$1);
    return byScore != 0 ? byScore : a.$2.name.compareTo(b.$2.name);
  });
  return [for (final (_, e) in scored) e];
}
