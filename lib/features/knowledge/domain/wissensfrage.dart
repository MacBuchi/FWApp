/// wissensfrage.dart – Die Wissensdatenbank hinter den Quizfragen
/// (Issue #174).
///
/// **Was es vorher gab und warum das keine Datenbank war.** Fragen lagen an
/// drei Stellen, die nichts voneinander wussten: 110 Katalog-Geräte trugen
/// Fragetexte *ohne Antworten* (gut für Karteikarten, nicht für ein Quiz),
/// 32 Fragen steckten im Asset des Party-Modus, und die Beladungs-Quizze
/// erzeugten ihre Fragen bei jedem Spiel neu und warfen sie weg. Man konnte
/// weder eine Frage suchen noch korrigieren noch eine eigene hinzufügen.
///
/// **Warum eine Frage MEHRERE richtige Antworten hat.** Der amtliche
/// Fragenkatalog des Innenministeriums Baden-Württemberg wurde ausgezählt:
/// Von 210 Lösungen haben nur 79 genau eine richtige Antwort — 63 % sind
/// Mehrfachantworten, bis zu acht richtige aus zehn. Eine Wissensdatenbank,
/// die nur einen Index speichert, kann echten Prüfungsstoff also zu gut
/// einem Drittel abbilden. Deshalb ist die Lösung eine **Menge**.
///
/// **Warum die Quelle vier Felder hat und kein Textfeld ist.** Man will nach
/// ihr filtern: Wird das Feuerwehrgesetz geändert, muss man alle Fragen mit
/// `FwG BW` wiederfinden können. In einem Fließtext findet man sie nicht.
///
/// **Warum es einen Geltungsbereich gibt.** Der Lernzielkatalog der
/// Truppmannausbildung belegt jedes Lernziel im Abschnitt „Rechtsgrundlagen"
/// mit einem Paragraphen des BADEN-WÜRTTEMBERGISCHEN Feuerwehrgesetzes; in
/// Bayern steht dort ein anderes Gesetz mit anderen Regeln. Fachliches aus
/// den Dienstvorschriften gilt dagegen bundesweit. Zwei Töpfe also, nicht
/// sechzehn.
///
/// **Wem die Fragen gehören: der Gesamtwehr.** Feuerwehrwissen ist nicht
/// abteilungsspezifisch — ein B-Schlauch hat überall denselben
/// Nenndurchmesser. Derselbe Weg wie bei den Gerätetypen (Stufe ②,
/// Issue #99): eine geteilte Tabelle, zeilenweise abgeglichen, statt des
/// Einzelschreiber-Snapshots. Zwei Gerätewarte, die gleichzeitig pflegen,
/// überschreiben sich damit nicht gegenseitig.
library;

/// Wovon eine Frage handelt.
///
/// Bewusst eine feste, kurze Liste statt freier Schlagworte: Kategorien, die
/// jeder selbst tippt, zerfallen binnen eines Jahres in „Technik",
/// „technik" und „Techn." — und dann filtert niemand mehr danach. Neue
/// Kategorien kommen über eine App-Version, nicht über ein Textfeld.
enum Wissensgebiet {
  fahrzeugkunde('fahrzeugkunde', 'Fahrzeugkunde', '🚒'),
  geraetekunde('geraetekunde', 'Gerätekunde', '🧰'),
  loeschlehre('loeschlehre', 'Löschlehre', '💧'),

  /// Eigener Lehrgang, eigener Lernzielkatalog — und im Prüfungsstoff so
  /// umfangreich, dass er unter „Gerätekunde" unauffindbar wäre.
  atemschutz('atemschutz', 'Atemschutz', '😷'),

  /// Taktische Einheiten, Befehlsgebung, Einsatzablauf — der Stoff der
  /// FwDV 3 und FwDV 100.
  einsatzlehre('einsatzlehre', 'Einsatzlehre und Taktik', '🧭'),
  technischeHilfe('technische_hilfe', 'Technische Hilfeleistung', '🛠️'),
  gefahrgut('gefahrgut', 'Gefahrgut', '☣️'),
  ersteHilfe('erste_hilfe', 'Erste Hilfe', '🚑'),
  rechtUndOrganisation('recht_organisation', 'Recht und Organisation', '📋'),
  funk('funk', 'Funk', '📻'),

  /// Der Topf aus dem Party-Modus, der bewusst nichts beweisen will
  /// (Issue #160). Er bleibt getrennt, damit niemand beim Lernen Klischees
  /// für Prüfungsstoff hält.
  klischee('klischee', 'Klischees', '😄');

  const Wissensgebiet(this.schluessel, this.label, this.symbol);

  /// Wert in Datenbank und Austauschformat — stabil, nie das Label.
  final String schluessel;
  final String label;
  final String symbol;

  static Wissensgebiet? ausSchluessel(String? wert) {
    for (final g in values) {
      if (g.schluessel == wert) return g;
    }
    return null;
  }

  /// Was zum Lernen zählt. Klischees gehören nicht dazu.
  static List<Wissensgebiet> get lernstoff =>
      values.where((g) => g != klischee).toList();
}

/// Wo eine Frage gilt.
enum Geltungsbereich {
  /// Fachliches aus den Feuerwehr-Dienstvorschriften und dem
  /// Unfallverhütungsrecht — in jedem Land dieselbe Antwort.
  bund('bund', 'Bundesweit'),

  /// Landesrecht: Feuerwehrgesetz, Rangordnung, Ausbildungsordnung.
  land('land', 'Landesrecht');

  const Geltungsbereich(this.schluessel, this.label);
  final String schluessel;
  final String label;

  static Geltungsbereich ausSchluessel(String? wert) => values.firstWhere(
        (g) => g.schluessel == wert,
        orElse: () => bund,
      );
}

/// Die Länderkürzel. Vollständig angelegt, damit ein zweites Land später
/// nichts umbauen muss — gefüllt wird vorerst nur Baden-Württemberg. Leere
/// Landesblöcke sind Ballast, kein Fortschritt.
const kBundeslaender = <String, String>{
  'BW': 'Baden-Württemberg',
  'BY': 'Bayern',
  'BE': 'Berlin',
  'BB': 'Brandenburg',
  'HB': 'Bremen',
  'HH': 'Hamburg',
  'HE': 'Hessen',
  'MV': 'Mecklenburg-Vorpommern',
  'NI': 'Niedersachsen',
  'NW': 'Nordrhein-Westfalen',
  'RP': 'Rheinland-Pfalz',
  'SL': 'Saarland',
  'SN': 'Sachsen',
  'ST': 'Sachsen-Anhalt',
  'SH': 'Schleswig-Holstein',
  'TH': 'Thüringen',
};

/// Woher der Inhalt einer Frage stammt — die Fundstelle, die in der App
/// unter der Frage steht.
///
/// Vier Felder statt eines Satzes, weil danach gefiltert wird. [stand] ist
/// die **Fassung** der Quelle, nicht das Abrufdatum: Eine Frage nach § 8 FwG
/// ist an die Gesetzesfassung gebunden, nicht daran, wann jemand nachgesehen
/// hat.
class Fragenquelle {
  /// „FwG BW", „FwDV 10", „DGUV Vorschrift 49".
  final String werk;

  /// „§ 8 Abs. 2", „Abschnitt 4.2". Leer, wenn das Werk als Ganzes gemeint
  /// ist.
  final String? fundstelle;

  /// Fassung der Quelle, z. B. `2010-03-02`.
  final String? stand;

  final String? url;

  const Fragenquelle({
    required this.werk,
    this.fundstelle,
    this.stand,
    this.url,
  });

  /// „FwG BW · § 8 Abs. 2" — was unter der Frage steht.
  String get anzeige =>
      fundstelle == null || fundstelle!.isEmpty ? werk : '$werk · $fundstelle';

  bool get istLeer => werk.trim().isEmpty;
}

/// Woher eine Frage stammt. Entscheidet, was man mit ihr tun darf.
enum Fragenherkunft {
  /// Mit der App ausgeliefert. Nicht löschbar — sonst wäre der Grundstock
  /// nach einem missglückten Aufräumen weg und käme nie wieder.
  mitgeliefert('mitgeliefert'),

  /// Von einem Menschen dieser Gesamtwehr eingebracht.
  eigen('eigen'),

  /// Aus der Beladung erzeugt („In welchem Fach liegt der Spreizer?").
  /// Steht nicht in der Datenbank, sondern entsteht beim Spielen — hier
  /// nur, damit die Oberfläche sie benennen kann.
  ausBeladung('aus_beladung');

  const Fragenherkunft(this.schluessel);
  final String schluessel;

  static Fragenherkunft ausSchluessel(String? wert) => values.firstWhere(
        (h) => h.schluessel == wert,
        orElse: () => eigen,
      );
}

/// Ist die Frage im Spiel?
///
/// Der Zwischenschritt ist Marcus' ausdrücklicher Wunsch: „Filterung, damit
/// kein blöder Unsinn in die Datenbank kommt." Einreichen darf jeder mit
/// Konto, freigeben nur der Gerätewart — die Frage ist bis dahin sichtbar,
/// aber sie wird nicht gestellt.
enum Fragenstand {
  eingereicht('eingereicht', 'Wartet auf Freigabe'),
  freigegeben('freigegeben', 'Freigegeben'),
  abgelehnt('abgelehnt', 'Abgelehnt');

  const Fragenstand(this.schluessel, this.label);
  final String schluessel;
  final String label;

  static Fragenstand ausSchluessel(String? wert) => values.firstWhere(
        (s) => s.schluessel == wert,
        orElse: () => eingereicht,
      );
}

/// Eine Frage der Wissensdatenbank.
class Wissensfrage {
  final int id;
  final Wissensgebiet gebiet;
  final String frage;
  final List<String> antworten;

  /// Die Indizes der richtigen Antworten in [antworten].
  ///
  /// Eine **Menge**, weil der amtliche Prüfungsstoff überwiegend
  /// Mehrfachantworten kennt (siehe Kopf). Indizes und keine Texte — zwei
  /// Antworten dürfen gleich lauten, und ein Textvergleich träfe dann die
  /// falsche.
  final Set<int> richtige;

  final String? erklaerung;
  final Fragenherkunft herkunft;
  final Fragenstand stand;

  /// Die Fundstelle. `null` nur bei Fragen, die vor Issue #174 entstanden
  /// sind — neue verlangen sie.
  final Fragenquelle? quelle;

  final Geltungsbereich geltung;

  /// Länderkürzel, nur bei [Geltungsbereich.land] gesetzt.
  final String? land;

  /// Wer sie eingebracht hat — Anzeigename, rein zur Nachvollziehbarkeit.
  final String? eingereichtVon;

  const Wissensfrage({
    required this.id,
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtige,
    this.erklaerung,
    this.herkunft = Fragenherkunft.eigen,
    this.stand = Fragenstand.eingereicht,
    this.quelle,
    this.geltung = Geltungsbereich.bund,
    this.land,
    this.eingereichtVon,
  });

  /// Genau eine richtige Antwort? Nur solche Fragen zieht der Party-Modus —
  /// am Tisch reihum ist Ankreuzen mehrerer Kästchen kein Spielzug.
  bool get istEinfachauswahl => richtige.length == 1;

  bool get spielbar => stand == Fragenstand.freigegeben;

  /// Ist [gewaehlt] die vollständig richtige Antwort?
  ///
  /// Vollständig heißt: **alle** richtigen und **keine** falsche. Ein
  /// „teilweise richtig" gibt es im Prüfungsbogen nicht, und es hier zu
  /// erfinden wäre eine andere Bewertung als die, auf die hin geübt wird.
  bool istRichtig(Set<int> gewaehlt) =>
      gewaehlt.length == richtige.length && gewaehlt.containsAll(richtige);

  /// Wo die Frage gilt, in einem Wort für die Anzeige.
  String get geltungAnzeige => geltung == Geltungsbereich.bund
      ? Geltungsbereich.bund.label
      : (kBundeslaender[land] ?? Geltungsbereich.land.label);

  /// Was ausgeliefert wurde, darf niemand löschen — nur abwählen.
  bool get loeschbar => herkunft != Fragenherkunft.mitgeliefert;
}

/// Prüft eine Frage, bevor sie in die Datenbank darf.
///
/// Die Regeln stehen hier und nicht im Formular: Dieselbe Prüfung muss den
/// CSV-Import bewachen, und zwei Fassungen derselben Regel laufen
/// auseinander. Rückgabe `null` heißt: in Ordnung.
String? pruefeFrage({
  required String frage,
  required List<String> antworten,
  required Set<int> richtige,
}) {
  final text = frage.trim();
  if (text.length < 8) {
    return 'Die Frage ist zu kurz — schreib sie bitte aus.';
  }
  if (!text.contains('?')) {
    return 'Das ist keine Frage. Es fehlt das Fragezeichen.';
  }

  final sauber = antworten.map((a) => a.trim()).toList();
  if (sauber.any((a) => a.isEmpty)) {
    return 'Eine Antwort ist leer.';
  }
  if (sauber.length < 2) {
    return 'Mindestens zwei Antworten — eine richtige und eine falsche.';
  }
  // Zehn, weil der amtliche Prüfungsstoff so weit geht: Im Fragenkatalog
  // des Innenministeriums BW laufen die Antwortkennungen bis „j)". Ein
  // engeres Limit (anfangs sechs) wäre eine Zahl aus dem Bauch gewesen und
  // hätte echte Fragen unerfassbar gemacht — derselbe Fehler wie ein
  // einzelner Index für die Lösung, nur kleiner.
  if (sauber.length > 10) {
    return 'Höchstens zehn Antworten.';
  }
  // Doppelte Antworten machen die Frage unbeantwortbar: Zwei gleiche Texte,
  // einer davon als richtig gewertet — das ist keine Frage, das ist eine
  // Falle.
  final ohneDoppelte = sauber.map((a) => a.toLowerCase()).toSet();
  if (ohneDoppelte.length != sauber.length) {
    return 'Zwei Antworten sind gleich.';
  }
  if (richtige.isEmpty) {
    return 'Es ist keine richtige Antwort markiert.';
  }
  if (richtige.any((i) => i < 0 || i >= sauber.length)) {
    return 'Eine markierte Antwort gibt es nicht.';
  }
  // Alle Antworten richtig ist keine Frage, sondern eine Aufzählung — und
  // im Prüfungsbogen kommt das nicht vor.
  if (richtige.length == sauber.length) {
    return 'Es müssen auch falsche Antworten dabei sein.';
  }
  return null;
}
