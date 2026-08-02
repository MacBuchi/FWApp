/// equipment_naming.dart – Wie ein Gerätename verglichen wird.
///
/// Lag bis Stufe ② als private Regel im Import-Matcher. Seit die Gerätetypen
/// der Gesamtwehr gehören (Issue #99), braucht sie auch der Typ-Sync: „C-Rohr"
/// und „C-ROHR!" sind derselbe Typ. Damit gilt die Regel an zwei Stellen —
/// und nach der Hausregel wandert sie dann nach `core/`, statt kopiert zu
/// werden.
///
/// ⚠️ Dieselbe Regel steht als `public.normalize_equipment_name` in
/// supabase/migrations/20260802160000_geraetetypen_gesamtwehr.sql. Wer eine
/// Seite ändert, ändert die andere mit — sonst dedupliziert der Server anders
/// als der Client, und aus einem Typ werden stillschweigend zwei.
library;

/// Kleinschreibung, Umlaute ausgeschrieben, alles andere zu einem Leerzeichen.
String normalizeEquipmentName(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
