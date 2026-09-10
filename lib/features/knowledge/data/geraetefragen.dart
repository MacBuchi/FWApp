/// geraetefragen.dart – Fragen, die den eigenen Fuhrpark kennen.
///
/// Marcus' Vorschlag: Die App weiß, welche Geräte auf den Fahrzeugen liegen —
/// dann soll sie auch danach fragen. Der mitgelieferte Katalog trug das
/// Material dafür längst und nutzte es nur halb: 110 Geräte mit
/// `typical_use`, `equipment_functions` und je zwei `training_questions`.
/// Die Trainingsfragen sind **Karteikarten ohne Antworten** — spielbar sind
/// sie nicht, und das bleiben sie hier auch.
///
/// **Warum erzeugt und nicht geschrieben.** Zweihundert Antwortsätze über
/// Feuerwehrgerät wären zweihundert Gelegenheiten, etwas zu erfinden. Aus
/// `typical_use` erzeugt, ist die richtige Antwort dagegen **per Konstruktion
/// die des Katalogs** — es kommt kein Satz vor, der nicht schon geprüft im
/// Asset stand. Was der Generator beisteuert, ist die Auswahl der falschen
/// Antworten, und dafür gibt es die zwei Regeln unten.
///
/// **Regel 1: keine generischen Verwendungen.** „Jeder Einsatz",
/// „Nachlöscharbeiten" — was bei mehreren Geräten steht, taugt weder als
/// richtige Antwort noch als Ablenker, weil es für zu vieles zutrifft.
///
/// **Regel 2: Ablenker nur aus fachfremden Geräten.** Zwei Lampen haben
/// austauschbare Verwendungen; steht die eine als Ablenker bei der anderen,
/// hat die Frage zwei richtige Antworten und ist unbeantwortbar. Deshalb
/// kommen Ablenker nur von Geräten, deren `equipment_functions` mit denen
/// des gefragten Geräts **keinen einzigen Eintrag teilen**.
///
/// Was trotzdem bleibt, ist die Möglichkeit einer unglücklichen Paarung —
/// „Nachlöscharbeiten an Dachstühlen" ist für einen D-Schlauch nicht absurd,
/// nur untypisch. Die Frage sagt deshalb „typischerweise", und seit v1.44.0
/// kann der Gerätewart jede Frage abschalten oder einen Hinweis dazu geben.
/// Das ist der Grund, warum diese Fragen als normale Zeilen in der
/// Wissensdatenbank landen und nicht beim Spielen entstehen: Was man
/// korrigieren können soll, muss man sehen können.
library;

import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

/// Eine erzeugte Frage, noch ohne Datenbankzeile.
class Geraetefrage {
  /// Katalog-ID des Geräts, um das es geht — `std_…`.
  final String geraet;

  final String frage;

  /// Die richtige Antwort steht an erster Stelle; gemischt wird erst beim
  /// Anlegen, damit der Test die Erwartung ohne Zufall prüfen kann.
  final String richtige;
  final List<String> falsche;

  final String erklaerung;

  const Geraetefrage({
    required this.geraet,
    required this.frage,
    required this.richtige,
    required this.falsche,
    required this.erklaerung,
  });
}

/// Wie viele falsche Antworten eine erzeugte Frage bekommt.
const _ablenker = 3;

/// Baut die Fragen aus dem Katalog. Ohne Zufall: Dieselbe Katalogfassung
/// ergibt immer dieselben Fragen, sonst legte jeder Start neue an.
List<Geraetefrage> baueGeraetefragen(StandardCatalog katalog) {
  final eintraege = [
    for (final id in katalog.ids)
      if (katalog.eintrag(id) case final e?) e,
  ];
  if (eintraege.length < _ablenker + 1) return const [];

  // Regel 1: Was bei mehr als einem Gerät steht, ist generisch.
  final haeufigkeit = <String, int>{};
  for (final e in eintraege) {
    for (final v in e.typischeVerwendung) {
      haeufigkeit[v] = (haeufigkeit[v] ?? 0) + 1;
    }
  }
  bool eigen(String v) => (haeufigkeit[v] ?? 0) == 1;

  final fragen = <Geraetefrage>[];
  for (final e in eintraege) {
    final eigene = e.typischeVerwendung.where(eigen).toList();
    if (eigene.isEmpty) continue;

    final meins = e.funktionen.toSet();
    // Regel 2: nur fachfremde Geräte als Ablenker-Quelle.
    final ablenker = <String>{
      for (final andere in eintraege)
        if (andere.id != e.id && meins.intersection(andere.funktionen.toSet()).isEmpty)
          ...andere.typischeVerwendung.where(eigen),
    }.toList()
      ..sort();
    if (ablenker.length < _ablenker) continue;

    // Deterministisch statt zufällig gezogen: Der Startpunkt hängt am Namen
    // des Geräts, sodass nicht alle Fragen dieselben drei Ablenker tragen,
    // aber ein zweiter Lauf dieselben liefert.
    final start = e.id.hashCode.abs() % ablenker.length;
    final gewaehlt = [
      for (var i = 0; i < _ablenker; i++) ablenker[(start + i) % ablenker.length],
    ];

    final richtige = eigene.first;
    fragen.add(Geraetefrage(
      geraet: e.id,
      frage: 'Wofür wird „${e.name}" typischerweise eingesetzt?',
      richtige: richtige,
      falsche: gewaehlt,
      erklaerung: e.beschreibung.isEmpty
          ? '${e.name}: $richtige.'
          : e.beschreibung,
    ));
  }
  return fragen;
}

/// Das Sachgebiet, unter dem die erzeugten Fragen einsortiert werden.
///
/// Gerätekunde und nicht Fahrzeugkunde: Gefragt wird nach dem Gerät, nicht
/// nach dem Wagen, auf dem es liegt.
const kGeraetefragenGebiet = Wissensgebiet.geraetekunde;

/// Die Fundstelle, die unter jeder erzeugten Frage steht.
///
/// Sie zu nennen ist keine Förmlichkeit: Wer beim Kameradschaftsabend über
/// eine Antwort streitet, soll sehen, dass sie aus dem mitgelieferten Katalog
/// stammt und nicht aus einer Dienstvorschrift — und dass sie deshalb
/// korrigierbar ist.
const kGeraetefragenQuelle = Fragenquelle(
  werk: 'Mitgelieferter Gerätekatalog',
  fundstelle: 'typische Verwendung',
);
