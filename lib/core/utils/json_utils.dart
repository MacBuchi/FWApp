/// json_utils.dart – Helpers for encoding/decoding JSON arrays stored in Drift TEXT columns.
library;
import 'dart:convert';

List<String> jsonToStringList(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {} // defekter Spalteninhalt → leere Liste statt Crash
  return [];
}

String stringListToJson(List<String> list) => jsonEncode(list);

Map<String, dynamic> jsonToMap(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {} // defekter Spalteninhalt → leere Map statt Crash
  return {};
}

String mapToJson(Map<String, dynamic> map) => jsonEncode(map);
