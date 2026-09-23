/// lerngruppe.dart – Lerngruppe und Mitglied, wie der Server sie herausgibt
/// (Issue #136), samt der Regeln, die der Bildschirm daraus ableitet.
///
/// Reine Dart-Logik ohne Flutter und ohne Supabase: Laufzeit, Sortierung,
/// Code-Prüfung und die Übersetzung der Servermeldungen lassen sich so ohne
/// Server prüfen. Die Regeln selbst (wer beitreten darf, wann eine Gruppe
/// abgelaufen ist) setzt der Server durch — hier steht nur, wie die App sie
/// anzeigt.
library;

/// Eine Lerngruppe, in der man Mitglied ist. Andere sieht man nicht — die
/// Lese-Policy gibt nur die eigenen heraus.
class Lerngruppe {
  final String id;
  final String gesamtwehrId;
  final String name;

  /// Sechs Ziffern, zum Vorlesen und Abtippen.
  final String code;

  /// Letzter Tag, an dem die Gruppe noch läuft (einschließlich).
  final DateTime laeuftBis;

  const Lerngruppe({
    required this.id,
    required this.gesamtwehrId,
    required this.name,
    required this.code,
    required this.laeuftBis,
  });

  factory Lerngruppe.fromJson(Map<String, dynamic> json) => Lerngruppe(
    id: json['id'] as String,
    gesamtwehrId: json['gesamtwehr_id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    // `date` kommt als „2026-11-18" — ohne Uhrzeit, also lokal gelesen.
    laeuftBis: DateTime.parse(json['laeuft_bis'] as String),
  );

  /// Wie der Server es sieht: `laeuft_bis >= current_date`. Am letzten Tag
  /// läuft die Gruppe also noch.
  bool laeuftAm(DateTime heute) => !_tag(laeuftBis).isBefore(_tag(heute));

  /// Volle Tage bis zum letzten Tag; 0 heißt „endet heute", negativ heißt
  /// beendet.
  int restTage(DateTime heute) =>
      _tag(laeuftBis).difference(_tag(heute)).inDays;

  /// Die Zeile unter dem Namen: „läuft noch 12 Tage", „endet heute",
  /// „beendet am 18.11.2026".
  String laufzeitText(DateTime heute) {
    final rest = restTage(heute);
    if (rest < 0) return 'beendet am ${datumText(laeuftBis)}';
    if (rest == 0) return 'endet heute';
    if (rest == 1) return 'läuft noch bis morgen';
    return 'läuft noch $rest Tage, bis ${datumText(laeuftBis)}';
  }

  /// Der Code in zwei Dreiergruppen — so wird er vorgelesen.
  String get codeLesbar => '${code.substring(0, 3)} ${code.substring(3)}';

  /// Der Text fürs Teilen-Blatt. Sagt, wo man den Code eintippt: Wer ihn
  /// im Chat bekommt, hat die App meist gerade nicht offen.
  String get einladungsText =>
      'Mach mit in der Lerngruppe „$name" in FWApp! '
      'Unter Lernen → Lerngruppen → „Mit Code beitreten" diesen Code '
      'eingeben: $codeLesbar';
}

/// Ein Mitglied, wie `lerngruppen_mitglieder_namen` es herausgibt: Name und
/// Avatar, sonst nichts.
class LerngruppenMitglied {
  final String userId;

  /// Anzeigename, Rückfall Nutzername (serverseitig). Kann bei einem Konto
  /// ohne beides trotzdem leer sein.
  final String? name;

  /// Kodierte Avatar-Konfiguration oder `null`.
  final String? avatar;
  final DateTime? beigetretenAm;

  const LerngruppenMitglied({
    required this.userId,
    this.name,
    this.avatar,
    this.beigetretenAm,
  });

  factory LerngruppenMitglied.fromJson(Map<String, dynamic> json) =>
      LerngruppenMitglied(
        userId: json['user_id'] as String,
        name: json['anzeigename'] as String?,
        avatar: json['avatar'] as String?,
        beigetretenAm: DateTime.tryParse(
          json['beigetreten_am'] as String? ?? '',
        ),
      );

  String get anzeigeName {
    final n = name?.trim();
    return n == null || n.isEmpty ? 'Unbenannt' : n;
  }
}

/// Laufende Gruppen zuerst, die am frühesten endende oben (sie braucht die
/// Aufmerksamkeit); dahinter die beendeten, die jüngste zuerst.
List<Lerngruppe> sortiereLerngruppen(
  Iterable<Lerngruppe> gruppen,
  DateTime heute,
) {
  final laufend = [
    for (final g in gruppen)
      if (g.laeuftAm(heute)) g,
  ]..sort((a, b) => a.laeuftBis.compareTo(b.laeuftBis));
  final beendet = [
    for (final g in gruppen)
      if (!g.laeuftAm(heute)) g,
  ]..sort((a, b) => b.laeuftBis.compareTo(a.laeuftBis));
  return [...laufend, ...beendet];
}

/// Holt aus einer Eingabe die sechs Ziffern heraus — wer „123 456" oder
/// „123-456" aus dem Chat kopiert, soll nicht an Leerzeichen scheitern.
/// `null`, wenn es nicht genau sechs Ziffern sind.
String? normalisiereCode(String eingabe) {
  final ziffern = eingabe.replaceAll(RegExp(r'[\s\-]'), '');
  return RegExp(r'^[0-9]{6}$').hasMatch(ziffern) ? ziffern : null;
}

/// Die Laufzeiten, die der Gründen-Dialog anbietet. Der Server nimmt 1–26
/// Wochen; die Auswahl hält es bei runden Werten um die „zwei Monate" aus
/// der Idee.
const kLerngruppenLaufzeiten = [4, 6, 8, 12];
const kLerngruppenStandardWochen = 8;

/// Die Servermeldungen sind deutsch, aber in ASCII („gehoert") und knapp.
/// Hier wird ein Satz daraus, der sagt, was als Nächstes zu tun ist.
/// Unbekanntes bleibt im Original — eine falsche Beruhigung wäre schlimmer
/// als eine fremde Meldung (wie `gesamtwehrFehlerText`).
String lerngruppeFehlerText(String roh) {
  if (roh.contains('Beitrittscode gibt es nicht')) {
    return 'Diesen Code gibt es nicht. Vertippt? Es sind sechs Ziffern.';
  }
  if (roh.contains('ist abgelaufen')) {
    return 'Diese Lerngruppe ist schon zu Ende. Frag nach dem Code einer '
        'laufenden — oder gründe selbst eine.';
  }
  if (roh.contains('anderen Feuerwehr')) {
    return 'Diese Lerngruppe gehört zu einer anderen Feuerwehr. Beitreten '
        'geht nur innerhalb der eigenen Gesamtwehr.';
  }
  if (roh.contains('Keine Berechtigung fuer diese Gesamtwehr')) {
    return 'Du gehörst nicht zu dieser Gesamtwehr und kannst darin keine '
        'Lerngruppe gründen.';
  }
  if (roh.contains('Laufzeit muss')) {
    return 'Eine Lerngruppe läuft zwischen einer und 26 Wochen.';
  }
  if (roh.contains('Kein freier Beitrittscode')) {
    return 'Gerade war kein Code frei. Bitte gleich noch einmal versuchen.';
  }
  // Der CHECK auf `name` (1–60 Zeichen nach dem Trimmen).
  if (roh.contains('lerngruppen_name_check')) {
    return 'Der Name muss zwischen 1 und 60 Zeichen lang sein.';
  }
  if (roh.contains('SocketException') ||
      roh.contains('ClientException') ||
      roh.contains('Failed host lookup')) {
    return 'Keine Verbindung zum Server. Lerngruppen brauchen Netz — '
        'das Lernen selbst geht auch ohne.';
  }
  return roh;
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

String datumText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';
