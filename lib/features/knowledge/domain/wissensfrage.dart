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

  /// Index der richtigen Antwort in [antworten].
  ///
  /// Als Index und nicht als Text — dieselbe Entscheidung wie im
  /// Party-Modus: Zwei Antworten dürfen gleich lauten, und ein Textvergleich
  /// träfe dann die falsche.
  final int richtig;

  final String? erklaerung;
  final Fragenherkunft herkunft;
  final Fragenstand stand;

  /// Wer sie eingebracht hat — Anzeigename, rein zur Nachvollziehbarkeit.
  final String? eingereichtVon;

  const Wissensfrage({
    required this.id,
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtig,
    this.erklaerung,
    this.herkunft = Fragenherkunft.eigen,
    this.stand = Fragenstand.eingereicht,
    this.eingereichtVon,
  });

  String get richtigeAntwort => antworten[richtig];

  bool get spielbar => stand == Fragenstand.freigegeben;

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
  required int richtig,
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
  if (sauber.length > 6) {
    return 'Höchstens sechs Antworten, sonst passt es auf kein Handy.';
  }
  // Doppelte Antworten machen die Frage unbeantwortbar: Zwei gleiche Texte,
  // einer davon als richtig gewertet — das ist keine Frage, das ist eine
  // Falle.
  final ohneDoppelte = sauber.map((a) => a.toLowerCase()).toSet();
  if (ohneDoppelte.length != sauber.length) {
    return 'Zwei Antworten sind gleich.';
  }
  if (richtig < 0 || richtig >= sauber.length) {
    return 'Es ist keine richtige Antwort markiert.';
  }
  return null;
}
