/// equipment_matcher.dart – Resolves raw Beladeliste equipment names against
/// the database: exact name → bundled aliases.json → learned UserAliases →
/// normalized fuzzy matching (token overlap + Levenshtein, pure Dart).
library;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/import/domain/import_models.dart';

class EquipmentMatcher {
  /// Score at or above which a fuzzy candidate becomes the yellow suggestion.
  static const fuzzyThreshold = 0.72;

  /// Minimum score for a candidate to appear in the suggestion list at all.
  static const suggestionThreshold = 0.35;

  final Map<String, MatchCandidate> _exactByName = {};
  final Map<String, MatchCandidate> _byAlias = {};
  final List<_IndexedEquipment> _index = [];

  /// [bundledAliases] is the content of assets/equipment_library/aliases.json:
  /// libraryEquipmentId → list of alias spellings.
  EquipmentMatcher({
    required List<EquipmentItemData> equipment,
    Map<String, List<String>> bundledAliases = const {},
    List<UserAliasData> userAliases = const [],
  }) {
    final byLibraryId = <String, EquipmentItemData>{};
    for (final item in equipment) {
      final candidate =
          MatchCandidate(equipmentId: item.id, equipmentName: item.name, score: 1);
      _exactByName[normalize(item.name)] = candidate;
      if (item.shortName != null && item.shortName!.isNotEmpty) {
        _byAlias.putIfAbsent(normalize(item.shortName!), () => candidate);
      }
      if (item.libraryEquipmentId != null) {
        byLibraryId[item.libraryEquipmentId!] = item;
      }
      _index.add(_IndexedEquipment(
        candidate: candidate,
        normalized: normalize(item.name),
        tokens: _tokens(item.name),
      ));
    }
    bundledAliases.forEach((libraryId, aliases) {
      final item = byLibraryId[libraryId];
      if (item == null) return;
      final candidate =
          MatchCandidate(equipmentId: item.id, equipmentName: item.name, score: 1);
      for (final alias in aliases) {
        _byAlias.putIfAbsent(normalize(alias), () => candidate);
      }
    });
    final byId = {for (final e in equipment) e.id: e};
    for (final alias in userAliases) {
      final item = byId[alias.equipmentId];
      if (item == null) continue;
      _byAlias[normalize(alias.alias)] = MatchCandidate(
          equipmentId: item.id, equipmentName: item.name, score: 1);
    }
  }

  EquipmentMatch match(String rawName) {
    final normalized = normalize(rawName);
    if (normalized.isEmpty) return const EquipmentMatch(kind: MatchKind.none);

    final exact = _exactByName[normalized];
    if (exact != null) {
      return EquipmentMatch(
          kind: MatchKind.exact, best: exact, suggestions: [exact]);
    }
    final alias = _byAlias[normalized];
    if (alias != null) {
      return EquipmentMatch(
          kind: MatchKind.alias, best: alias, suggestions: [alias]);
    }

    // Fuzzy: rank all items, keep the top 3 above the suggestion threshold.
    final tokens = _tokens(rawName);
    final scored = <MatchCandidate>[];
    for (final entry in _index) {
      final score = _similarity(normalized, tokens, entry);
      if (score >= suggestionThreshold) {
        scored.add(MatchCandidate(
          equipmentId: entry.candidate.equipmentId,
          equipmentName: entry.candidate.equipmentName,
          score: score,
        ));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final suggestions = scored.take(3).toList();
    if (suggestions.isNotEmpty && suggestions.first.score >= fuzzyThreshold) {
      return EquipmentMatch(
          kind: MatchKind.fuzzy,
          best: suggestions.first,
          suggestions: suggestions);
    }
    return EquipmentMatch(kind: MatchKind.none, suggestions: suggestions);
  }

  // ── Normalization & similarity ──

  /// Lowercase, fold umlauts, strip punctuation, collapse whitespace.
  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static Set<String> _tokens(String s) =>
      normalize(s).split(' ').where((t) => t.length > 1).toSet();

  /// Combines token overlap (Sørensen–Dice over token sets) with a
  /// normalized Levenshtein ratio; the higher of the two wins.
  static double _similarity(
      String normalized, Set<String> tokens, _IndexedEquipment entry) {
    double dice = 0;
    if (tokens.isNotEmpty && entry.tokens.isNotEmpty) {
      final common = tokens.intersection(entry.tokens).length;
      dice = 2 * common / (tokens.length + entry.tokens.length);
    }
    // Levenshtein is O(n*m); skip it for very unequal lengths where the
    // ratio cannot reach the suggestion threshold anyway.
    final a = normalized;
    final b = entry.normalized;
    final maxLen = a.length > b.length ? a.length : b.length;
    final minLen = a.length < b.length ? a.length : b.length;
    double lev = 0;
    if (maxLen > 0 && minLen / maxLen >= suggestionThreshold) {
      lev = 1 - _levenshtein(a, b) / maxLen;
    }
    return dice > lev ? dice : lev;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }
}

class _IndexedEquipment {
  final MatchCandidate candidate;
  final String normalized;
  final Set<String> tokens;
  _IndexedEquipment({
    required this.candidate,
    required this.normalized,
    required this.tokens,
  });
}
