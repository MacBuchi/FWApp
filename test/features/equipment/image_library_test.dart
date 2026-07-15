/// image_library_test.dart – Bildbibliothek: Vollständigkeit der Piktogramme
/// (jede Katalog-ID hat ein PNG) und intuitive Suche (Ranking, Aliasse,
/// Umlaute).
library;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/presentation/providers/image_library_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('jede Katalog-ID hat ein Piktogramm-PNG (Konvention <id>.png)', () {
    final catalog = jsonDecode(
            File('assets/equipment_library/catalog/standard_catalog.json')
                .readAsStringSync()) as Map<String, dynamic>;
    final missing = [
      for (final item in (catalog['items'] as List))
        if (!File(pictogramPath((item as Map)['id'] as String)).existsSync())
          item['id']
    ];
    expect(missing, isEmpty,
        reason: 'Piktogramme fehlen (tool/generate_pictograms.py laufen '
            'lassen): $missing');
  });

  group('searchImageLibrary', () {
    late List<ImageLibraryEntry> entries;

    setUpAll(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      entries = await container.read(imageLibraryProvider.future);
    });

    test('lädt alle Katalog-Einträge mit Piktogramm-Pfad', () {
      expect(entries.length, 110);
      expect(entries.every((e) => isPictogramPath(e.assetPath)), isTrue);
    });

    test('leere Suche liefert alles alphabetisch', () {
      final all = searchImageLibrary(entries, '');
      expect(all.length, entries.length);
      expect(all.first.name.compareTo(all.last.name), isNegative);
    });

    test('Alias-Treffer: „Pylone“ findet den Leitkegel zuerst', () {
      final results = searchImageLibrary(entries, 'Pylone');
      expect(results, isNotEmpty);
      expect(results.first.id, 'std_leitkegel');
    });

    test('Kurzform: „TS“ findet die Tragkraftspritze zuerst', () {
      final results = searchImageLibrary(entries, 'TS');
      expect(results.first.id, 'std_tragkraftspritze');
    });

    test('Wortanfang schlägt Teiltreffer: „schlauch“ listet Schläuche vorn',
        () {
      final results = searchImageLibrary(entries, 'schlauch');
      expect(results.length, greaterThan(4));
      // Vorn stehen Einträge, deren Name mit „Schlauch“ beginnt (z. B.
      // Schlauchhalter), nicht solche mit „…schlauch“ mittendrin.
      expect(results.first.name.toLowerCase(), startsWith('schlauch'));
      expect(results.map((e) => e.id),
          contains('std_b_druckschlauch_20m'));
    });

    test('Umlaut-tolerant: „Lüfter“ und „Luefter“ finden den Drucklüfter',
        () {
      for (final q in ['Lüfter', 'Luefter']) {
        final results = searchImageLibrary(entries, q);
        expect(results.map((e) => e.id), contains('std_druckbeluefter'),
            reason: 'Suche nach $q');
      }
    });

    test('Unsinn liefert leere Liste', () {
      expect(searchImageLibrary(entries, 'xyzzy quux'), isEmpty);
    });
  });
}
