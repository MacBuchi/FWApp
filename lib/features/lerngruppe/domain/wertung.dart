/// wertung.dart – Wochenaufgabe, Wochenwert und Rangliste der Lerngruppen
/// (Issue #136), ohne Flutter und ohne Server.
///
/// Was hier gerechnet wird, bestimmt, was das Gerät verlässt — deshalb
/// stehen die Regeln an EINER Stelle und sind ohne Server prüfbar:
///
///   * Der Wochenwert ist die Trefferquote in Prozent, gemittelt über die
///     letzten ZWEI Runden der laufenden Kalenderwoche im Modus der
///     Wochenaufgabe (Marcus, 2026-09-23). So zählt Verbesserung, eine
///     Glücksrunde allein aber nicht, und Spielzeit gar nicht.
///   * Nur diese eine Zahl geht zum Server (`melde_lerngruppen_wert`). Welche
///     Frage falsch war, bleibt auf dem Gerät.
library;

/// Die Modi, die Wochenaufgabe werden können — dieselben vier wie im CHECK
/// der Tabelle `lerngruppen_wertungen`. Karteikarten fehlen mit Absicht:
/// Dort sagt man selbst, ob man es wusste.
enum Lernmodus {
  fachQuiz('compartment', 'Fach-Quiz'),
  bildErkennung('image_recognition', 'Bild-Erkennung'),
  woLiegts('cutaway', 'Wo liegt\'s?'),
  dragDrop('dragdrop', 'Drag & Drop');

  /// Der Wert in `QuizResults.quizType` und auf dem Server.
  final String schluessel;
  final String titel;
  const Lernmodus(this.schluessel, this.titel);

  static Lernmodus? aus(String schluessel) {
    for (final m in values) {
      if (m.schluessel == schluessel) return m;
    }
    return null;
  }
}

/// Die Aufgabe der laufenden Woche, wie der Server sie ableitet.
class Wochenaufgabe {
  /// Montag der Kalenderwoche (lokal, 00:00).
  final DateTime woche;
  final Lernmodus modus;
  const Wochenaufgabe({required this.woche, required this.modus});

  /// `null`, wenn der Server einen Modus nennt, den diese App nicht kennt —
  /// dann lieber keine Aufgabe zeigen als eine falsche melden.
  static Wochenaufgabe? fromJson(Map<String, dynamic> json) {
    final modus = Lernmodus.aus(json['modus'] as String? ?? '');
    final woche = DateTime.tryParse(json['woche'] as String? ?? '');
    if (modus == null || woche == null) return null;
    return Wochenaufgabe(woche: woche, modus: modus);
  }
}

/// Eine Runde aus der lokalen Ergebnistabelle — nur, was die Rechnung
/// braucht.
typedef Runde = ({String quizType, int score, int total, DateTime playedAt});

/// Der eigene Wert der Woche in Prozent, oder `null`, wenn diese Woche
/// noch keine Runde im Aufgaben-Modus gespielt wurde (dann wird nichts
/// gemeldet — „0 %" wäre eine Behauptung, keine Messung).
int? wochenwert(Iterable<Runde> runden, Wochenaufgabe aufgabe) {
  final zaehlend = [
    for (final r in runden)
      if (r.quizType == aufgabe.modus.schluessel &&
          r.total > 0 &&
          !r.playedAt.isBefore(aufgabe.woche))
        r,
  ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  if (zaehlend.isEmpty) return null;
  final letzte = zaehlend.take(2).toList();
  final summe = letzte.fold<double>(0, (s, r) => s + r.score / r.total * 100);
  return (summe / letzte.length).round().clamp(0, 100);
}

/// Ein gemeldeter Wert, wie `lerngruppen_wertungen` ihn herausgibt.
class Wertung {
  final String userId;
  final DateTime woche;
  final int wert;
  const Wertung({
    required this.userId,
    required this.woche,
    required this.wert,
  });

  factory Wertung.fromJson(Map<String, dynamic> json) => Wertung(
    userId: json['user_id'] as String,
    woche: DateTime.parse(json['woche'] as String),
    wert: (json['wert'] as num).toInt(),
  );
}

/// Eine Zeile der Rangliste.
class Platzierung {
  final String userId;

  /// Platz 1, 1, 3 bei Gleichstand; `null` für „noch nichts gemeldet".
  final int? platz;

  /// Diese Woche: der Wochenwert. Gesamt: die Summe der Wochenwerte.
  final int? punkte;
  const Platzierung({required this.userId, this.platz, this.punkte});
}

/// Rangliste der Woche [woche]: wer gemeldet hat, nach Wert; dahinter alle
/// übrigen Mitglieder ohne Platz — sie sollen sehen, dass sie noch
/// einsteigen können, statt nicht vorzukommen.
List<Platzierung> wochenRangliste(
  Iterable<String> mitglieder,
  Iterable<Wertung> wertungen,
  DateTime woche,
) {
  final werte = {
    for (final w in wertungen)
      if (_gleicherTag(w.woche, woche)) w.userId: w.wert,
  };
  return _rangiere(mitglieder, werte);
}

/// Gesamtwertung: Summe der Wochenwerte. Summe statt Schnitt, weil jede
/// Woche zählen soll, in der man dabei war — die Gruppe lebt davon, dass
/// man wiederkommt. Wer eine Woche auslässt, verliert diese Woche, nicht
/// seinen Schnitt.
List<Platzierung> gesamtRangliste(
  Iterable<String> mitglieder,
  Iterable<Wertung> wertungen,
) {
  final summen = <String, int>{};
  for (final w in wertungen) {
    summen[w.userId] = (summen[w.userId] ?? 0) + w.wert;
  }
  return _rangiere(mitglieder, summen);
}

List<Platzierung> _rangiere(
  Iterable<String> mitglieder,
  Map<String, int> punkte,
) {
  // Nur wer (noch) Mitglied ist, steht in der Liste. Der Server räumt die
  // Werte beim Verlassen ohnehin mit ab; das hier fängt nur den Moment
  // zwischen zwei Abrufen.
  final alle = mitglieder.toList();
  final mit = [
    for (final m in alle)
      if (punkte.containsKey(m)) m,
  ]..sort((a, b) {
    final nachPunkten = punkte[b]!.compareTo(punkte[a]!);
    // Dart sortiert nicht stabil — bei Gleichstand entscheidet deshalb
    // ausdrücklich die Beitrittsreihenfolge, sonst tauschen zwei
    // Gleichauf-Liegende bei jedem Neuladen die Zeile.
    return nachPunkten != 0
        ? nachPunkten
        : alle.indexOf(a).compareTo(alle.indexOf(b));
  });
  final ergebnis = <Platzierung>[];
  for (var i = 0; i < mit.length; i++) {
    final gleichAufMitVorigem = i > 0 && punkte[mit[i]] == punkte[mit[i - 1]];
    ergebnis.add(
      Platzierung(
        userId: mit[i],
        platz: gleichAufMitVorigem ? ergebnis[i - 1].platz : i + 1,
        punkte: punkte[mit[i]],
      ),
    );
  }
  return [
    ...ergebnis,
    for (final m in alle)
      if (!punkte.containsKey(m)) Platzierung(userId: m),
  ];
}

bool _gleicherTag(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Meldet für jede LAUFENDE Gruppe den eigenen Wochenwert. Die drei
/// Zugriffe kommen als Funktionen herein, damit die Reihenfolge und das
/// Verhalten bei Fehlern ohne Server prüfbar sind.
///
/// ⚠️ Kein Puffer, keine Warteschlange (AGENTS.md: keine Offline-Write-
/// Queues): Was hier scheitert, wird beim nächsten Aufruf aus den lokalen
/// Runden neu gerechnet. Deshalb darf ein Fehler bei einer Gruppe die
/// anderen nicht aufhalten — er wird gemeldet und übergangen.
///
/// Gibt zurück, für wie viele Gruppen gemeldet wurde.
Future<int> meldeAlleWochenwerte({
  required Iterable<({String id, bool laeuft})> gruppen,
  required Future<Wochenaufgabe?> Function(String gruppeId) aufgabe,
  required Future<List<Runde>> Function(DateTime seit) runden,
  required Future<void> Function(String gruppeId, Lernmodus modus, int wert)
  melde,
  void Function(String gruppeId, Object fehler)? beiFehler,
}) async {
  var gemeldet = 0;
  for (final g in gruppen) {
    if (!g.laeuft) continue;
    try {
      final a = await aufgabe(g.id);
      if (a == null) continue;
      final wert = wochenwert(await runden(a.woche), a);
      if (wert == null) continue;
      await melde(g.id, a.modus, wert);
      gemeldet++;
    } catch (e) {
      beiFehler?.call(g.id, e);
    }
  }
  return gemeldet;
}
