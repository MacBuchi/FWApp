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

/// Wie ähnlich sind sich zwei Gerätenamen? 0 = nichts gemeinsam, 1 = gleich.
///
/// Lag bis Issue #67 als private Regel im Import-Matcher. Jetzt braucht sie
/// auch die Dublettenprüfung vor dem Veröffentlichen — dieselbe Frage
/// („meinen die beiden dasselbe Gerät?"), also dieselbe Rechnung. Zwei
/// Kopien liefen unweigerlich auseinander, und dann schlüge der Import einen
/// Treffer vor, den die Dublettenprüfung nicht sieht.
double aehnlichkeitVonNamen(String a, String b) => aehnlichkeitVorbereitet(
  normalizeEquipmentName(a),
  namensTokens(a),
  normalizeEquipmentName(b),
  namensTokens(b),
);

/// Dieselbe Rechnung mit vorbereiteten Werten — für Aufrufer, die über
/// hunderte Namen laufen und nicht jedes Mal neu normalisieren wollen.
double aehnlichkeitVorbereitet(
  String normA,
  Set<String> tokenA,
  String normB,
  Set<String> tokenB,
) {
  // Zwei Maße, das größere gewinnt. Sørensen-Dice über die Wortmengen fängt
  // Umstellungen und Abkürzungen („Werkzeugkasten DIN 14881 Feuerwehr"),
  // Levenshtein die Tippfehler und Endungen („Schlauchhalter" /
  // „Schlauchhalterung"). Keines von beiden allein reicht.
  var dice = 0.0;
  if (tokenA.isNotEmpty && tokenB.isNotEmpty) {
    final gemeinsam = tokenA.intersection(tokenB).length;
    dice = 2 * gemeinsam / (tokenA.length + tokenB.length);
  }
  // Levenshtein ist O(n*m); bei sehr ungleichen Längen kann das Verhältnis
  // die Schwelle ohnehin nicht erreichen, also gar nicht erst rechnen.
  final maxLen = normA.length > normB.length ? normA.length : normB.length;
  final minLen = normA.length < normB.length ? normA.length : normB.length;
  var lev = 0.0;
  if (maxLen > 0 && minLen / maxLen >= 0.35) {
    lev = 1 - _levenshtein(normA, normB) / maxLen;
  }
  return dice > lev ? dice : lev;
}

/// Die Wörter eines Namens, normalisiert. Einzelbuchstaben fallen heraus:
/// Das „C" in „C-Rohr" ist die Kupplungsgröße, kein Wort — es als Treffer
/// zu zählen machte jedes C-Gerät jedem anderen ähnlich.
Set<String> namensTokens(String s) =>
    normalizeEquipmentName(s).split(' ').where((t) => t.length > 1).toSet();

int _levenshtein(String a, String b) {
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

/// Kleinschreibung, Umlaute ausgeschrieben, alles andere zu einem Leerzeichen.
String normalizeEquipmentName(String s) =>
    s
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
