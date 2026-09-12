/// fragen_import.dart – Fragen aus einer Tabelle einlesen.
///
/// **Wozu.** Die Wissensdatenbank hat inhaltliche Lücken, die niemand durch
/// Eintippen schließt: Atemschutz stand bei sechs Fragen, Erste Hilfe bei
/// null. Wer vierzig Fragen aus einem Lernzielkatalog überträgt, will sie
/// nicht einzeln durch ein Formular geben.
///
/// **Warum ein festes Format statt eines Zuordnungs-Assistenten.** Der
/// Beladelisten-Import (`import_wizard_screen.dart`) hat einen, und das ist
/// dort richtig: Er liest fremde Exporte, deren Spalten niemand vorgibt. Hier
/// ist es umgekehrt — die Vorlage kommt aus dieser App. Ein Assistent für
/// Spalten, die man selbst ausgibt, wäre eine Zuordnung von etwas auf sich
/// selbst. Stattdessen: eine Kopfzeile mit festen Namen und eine Vorlage zum
/// Herunterladen ([vorlageCsv]).
///
/// **Warum jede Zeile einzeln scheitern darf.** Eine Datei mit vierzig Fragen
/// und zwei Tippfehlern ist kein Fehlschlag, sondern achtunddreißig gute
/// Fragen und zwei Zeilen zum Nachbessern. Ein „Import fehlgeschlagen" über
/// dem Ganzen würde die Datei unbrauchbar machen und den Fehler nicht zeigen.
library;

import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

/// Höchstzahl der Antwortspalten — dieselbe Grenze wie in [pruefeFrage].
const kMaxAntwortSpalten = 10;

/// Eine eingelesene Zeile: entweder eine Frage oder ein Grund, warum nicht.
class FrageImportZeile {
  /// Zeilennummer in der Datei, **mit Kopfzeile gezählt** — also die Nummer,
  /// die der Tabellenkalkulation anzeigt. Alles andere zwingt zum Nachzählen.
  final int zeile;

  /// Die Frage, wenn die Zeile in Ordnung war.
  final ImportierteFrage? frage;

  /// Warum die Zeile nicht ging. `null` heißt: Sie ging.
  final String? fehler;

  /// Eine Frage mit diesem Wortlaut steht schon im Bestand.
  final bool doppelt;

  const FrageImportZeile({
    required this.zeile,
    this.frage,
    this.fehler,
    this.doppelt = false,
  });

  bool get uebernehmbar => frage != null && fehler == null && !doppelt;
}

/// Was aus einer Zeile wird, bevor es eine Datenbankzeile ist.
class ImportierteFrage {
  final Wissensgebiet gebiet;
  final String frage;
  final List<String> antworten;
  final Set<int> richtige;
  final String? erklaerung;
  final String? kapitel;
  final Fragenquelle? quelle;
  final Geltungsbereich geltung;
  final String? land;
  final String? geraet;

  const ImportierteFrage({
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtige,
    this.erklaerung,
    this.kapitel,
    this.quelle,
    this.geltung = Geltungsbereich.bund,
    this.land,
    this.geraet,
  });
}

/// Das Ergebnis eines Einlesevorgangs.
class FrageImportErgebnis {
  final List<FrageImportZeile> zeilen;

  /// Spalten in der Kopfzeile, die niemand kennt. Kein Fehler — aber der
  /// häufigste Grund, warum eine Spalte „nicht ankommt", ist ein Tippfehler
  /// in ihrem Namen, und den sieht man sonst nirgends.
  final List<String> unbekannteSpalten;

  const FrageImportErgebnis({
    required this.zeilen,
    this.unbekannteSpalten = const [],
  });

  List<FrageImportZeile> get uebernehmbare =>
      zeilen.where((z) => z.uebernehmbar).toList();
  List<FrageImportZeile> get fehlerhafte =>
      zeilen.where((z) => z.fehler != null).toList();
  List<FrageImportZeile> get doppelte =>
      zeilen.where((z) => z.doppelt && z.fehler == null).toList();
}

/// Die Spaltennamen, die verstanden werden.
///
/// Kleinschreibung und ohne Leerzeichen verglichen — „Frage", „frage" und
/// „FRAGE" sind dasselbe, und wer aus Excel kopiert, hat oft ein Leerzeichen
/// hinten dran.
const _spalten = <String, String>{
  'frage': 'frage',
  'gebiet': 'gebiet',
  'kapitel': 'kapitel',
  'richtig': 'richtig',
  'richtige': 'richtig',
  'erklaerung': 'erklaerung',
  'erklärung': 'erklaerung',
  'quelle': 'quelle',
  'werk': 'quelle',
  'fundstelle': 'fundstelle',
  'stand': 'stand',
  'url': 'url',
  'geltung': 'geltung',
  'land': 'land',
  'geraet': 'geraet',
  'gerät': 'geraet',
};

String _norm(String s) => s.toLowerCase().trim();

/// Liest eine Tabelle ein. Wirft nur, wenn die Kopfzeile fehlt — alles
/// andere ist ein Befund an einer Zeile, kein Abbruch.
FrageImportErgebnis leseFragen(
  ImportTable tabelle, {
  /// Wortlaute, die es schon gibt — zum Erkennen von Doppelten. Normalisiert
  /// wie im Seeder.
  Set<String> vorhandeneFragen = const {},
}) {
  if (tabelle.rows.isEmpty) {
    throw const FormatException('Die Datei enthält keine Zeilen.');
  }

  final kopf = tabelle.rows.first.map(_norm).toList();
  final position = <String, int>{};
  final antwortSpalten = <int, int>{}; // Spaltenindex -> Antwortnummer
  final unbekannt = <String>[];

  for (var i = 0; i < kopf.length; i++) {
    final name = kopf[i];
    if (name.isEmpty) continue;
    final antwort = RegExp(r'^antwort\s*(\d+)$').firstMatch(name);
    if (antwort != null) {
      antwortSpalten[i] = int.parse(antwort.group(1)!);
      continue;
    }
    final feld = _spalten[name];
    if (feld == null) {
      unbekannt.add(tabelle.rows.first[i]);
      continue;
    }
    position.putIfAbsent(feld, () => i);
  }

  if (!position.containsKey('frage')) {
    throw const FormatException(
        'In der Kopfzeile fehlt die Spalte „frage". Lade dir die Vorlage '
        'herunter, wenn du unsicher bist.');
  }
  if (antwortSpalten.isEmpty) {
    throw const FormatException(
        'Es gibt keine Spalte „antwort1". Ohne Antworten ist es keine Frage.');
  }

  // Nach Antwortnummer sortiert, damit „antwort10" nicht zwischen 1 und 2
  // landet — die Reihenfolge entscheidet, worauf sich „richtig" bezieht.
  final sortierteAntworten = antwortSpalten.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final gesehen = <String>{...vorhandeneFragen};
  final zeilen = <FrageImportZeile>[];

  for (var r = 1; r < tabelle.rows.length; r++) {
    final row = tabelle.rows[r];
    String zelle(String feld) {
      final i = position[feld];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    final text = zelle('frage');
    if (text.isEmpty) continue; // Leerzeile — kein Befund, nur nichts.

    final antworten = <String>[
      for (final e in sortierteAntworten)
        if (e.key < row.length && row[e.key].trim().isNotEmpty)
          row[e.key].trim(),
    ];

    final richtigeRoh = zelle('richtig');
    final richtige = _leseRichtige(richtigeRoh, antworten.length);
    if (richtige == null) {
      zeilen.add(FrageImportZeile(
        zeile: r + 1,
        fehler: richtigeRoh.isEmpty
            ? 'Die Spalte „richtig" ist leer.'
            : 'Mit „$richtigeRoh" ist nicht zu erkennen, welche Antwort '
                'richtig ist. Erlaubt sind Nummern (1, 2) oder Buchstaben '
                '(a, b), mehrere durch Komma getrennt.',
      ));
      continue;
    }

    // Dieselbe Prüfung wie im Formular — die Regeln stehen an EINER Stelle,
    // sonst laufen Import und Eingabe auseinander.
    final beanstandung = pruefeFrage(
      frage: text,
      antworten: antworten,
      richtige: richtige,
    );
    if (beanstandung != null) {
      zeilen.add(FrageImportZeile(zeile: r + 1, fehler: beanstandung));
      continue;
    }

    final gebietRoh = zelle('gebiet');
    final gebiet = _leseGebiet(gebietRoh);
    if (gebiet == null) {
      zeilen.add(FrageImportZeile(
        zeile: r + 1,
        fehler: gebietRoh.isEmpty
            ? 'Die Spalte „gebiet" ist leer.'
            : 'Das Sachgebiet „$gebietRoh" gibt es nicht.',
      ));
      continue;
    }

    final werk = zelle('quelle');
    final geltungRoh = _norm(zelle('geltung'));
    final geltung = geltungRoh == 'land'
        ? Geltungsbereich.land
        : Geltungsbereich.bund;
    final land = zelle('land').toUpperCase();
    if (geltung == Geltungsbereich.land && !kBundeslaender.containsKey(land)) {
      zeilen.add(FrageImportZeile(
        zeile: r + 1,
        fehler: 'Bei „geltung: land" braucht es ein Länderkürzel in der '
            'Spalte „land" (z. B. BW).',
      ));
      continue;
    }

    zeilen.add(FrageImportZeile(
      zeile: r + 1,
      // Doppelte auch INNERHALB der Datei erkennen, nicht nur gegen den
      // Bestand: Eine Datei, die dieselbe Frage zweimal enthält, legt sie
      // sonst zweimal an, und das fällt erst beim Lernen auf.
      doppelt: !gesehen.add(schluesselFuer(text)),
      frage: ImportierteFrage(
        gebiet: gebiet,
        frage: text,
        antworten: antworten,
        richtige: richtige,
        erklaerung: zelle('erklaerung').isEmpty ? null : zelle('erklaerung'),
        kapitel: zelle('kapitel').isEmpty ? null : zelle('kapitel'),
        quelle: werk.isEmpty
            ? null
            : Fragenquelle(
                werk: werk,
                fundstelle:
                    zelle('fundstelle').isEmpty ? null : zelle('fundstelle'),
                stand: zelle('stand').isEmpty ? null : zelle('stand'),
                url: zelle('url').isEmpty ? null : zelle('url'),
              ),
        geltung: geltung,
        land: geltung == Geltungsbereich.land ? land : null,
        geraet: zelle('geraet').isEmpty ? null : zelle('geraet'),
      ),
    ));
  }

  return FrageImportErgebnis(zeilen: zeilen, unbekannteSpalten: unbekannt);
}

/// Der Wortlaut-Schlüssel zum Erkennen von Doppelten — wortgleich mit dem
/// des Seeders, damit Import und Grundstock dieselbe Frage für dieselbe
/// halten.
String schluesselFuer(String frage) =>
    frage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Liest „1", „1,3", „a", „a; c", „b und d".
///
/// ⚠️ **Menschen zählen ab eins, die Datenbank ab null.** Diese Umrechnung
/// ist der klassische Fehler um genau eins: Übersieht man sie, ist bei jeder
/// importierten Frage die Antwort daneben — und zwar systematisch, was
/// schlimmer ist als zufällig, weil es plausibel aussieht.
Set<int>? _leseRichtige(String roh, int anzahlAntworten) {
  final teile = roh
      .split(RegExp(r'[,;/ ]+|\bund\b'))
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();
  if (teile.isEmpty) return null;

  final indizes = <int>{};
  for (final t in teile) {
    // Buchstaben: a -> 0, b -> 1 …  Auch „a)" und „b." kommen vor.
    final buchstabe = RegExp(r'^([a-j])[).:]?$').firstMatch(t);
    if (buchstabe != null) {
      indizes.add(buchstabe.group(1)!.codeUnitAt(0) - 'a'.codeUnitAt(0));
      continue;
    }
    final zahl = int.tryParse(t.replaceAll(RegExp(r'[).:]'), ''));
    if (zahl == null || zahl < 1) return null;
    indizes.add(zahl - 1);
  }
  if (indizes.any((i) => i >= anzahlAntworten)) return null;
  return indizes;
}

/// Nimmt den Schlüssel („atemschutz") wie das Label („Atemschutz").
Wissensgebiet? _leseGebiet(String roh) {
  final n = _norm(roh);
  if (n.isEmpty) return null;
  for (final g in Wissensgebiet.values) {
    if (g.schluessel == n || _norm(g.label) == n) return g;
  }
  return null;
}

/// Die Vorlage zum Herunterladen — Kopfzeile und zwei Beispielzeilen.
///
/// Die Beispiele sind echte Fragen und keine Platzhalter: „Beispielfrage 1"
/// zeigt nicht, wie eine Quellenangabe aussieht oder wie man zwei richtige
/// Antworten markiert, und genau daran scheitert der erste Versuch sonst.
String vorlageCsv() {
  const kopf =
      'frage;gebiet;kapitel;antwort1;antwort2;antwort3;antwort4;richtig;'
      'erklaerung;quelle;fundstelle;stand;url;geltung;land;geraet';
  const zeile1 =
      'Wie lange darf ein Atemschutzgeraetetraeger hoechstens eingesetzt '
      'werden?;atemschutz;Einsatzgrundsaetze;Bis zum Ansprechen der '
      'Warneinrichtung;Beliebig lange;Genau 10 Minuten;Bis der Vorrat leer '
      'ist;1;Der Rueckweg muss immer gesichert sein.;FwDV 7;Abschnitt 6;;;'
      'bund;;';
  const zeile2 =
      'Welche Aufgaben hat der Angriffstrupp?;einsatzlehre;;'
      'Menschenrettung;Brandbekaempfung;Verkehrsabsicherung;'
      'Wasserentnahme;a, b;Mehrere Antworten sind richtig - durch Komma '
      'getrennt.;FwDV 3;Abschnitt 4;;;bund;;';
  return '$kopf\n$zeile1\n$zeile2\n';
}
