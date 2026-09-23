/// wertung_test.dart – Was aus den lokalen Runden wird, bevor es das Gerät
/// verlässt, und wie die Rangliste daraus entsteht (Issue #136).
///
/// Die Regeln sind Marcus' Entscheidungen vom 2026-09-23: Trefferquote,
/// Schnitt der letzten zwei Runden der Kalenderwoche, nur im Modus der
/// Wochenaufgabe, keine Karteikarten.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/lerngruppe/domain/wertung.dart';
import 'package:fwapp/features/lerngruppe/presentation/widgets/lerngruppen_karte.dart';

final _montag = DateTime(2026, 9, 21);
final _aufgabe = Wochenaufgabe(woche: _montag, modus: Lernmodus.fachQuiz);

Runde _runde(
  int score,
  int total, {
  String typ = 'compartment',
  DateTime? am,
}) => (quizType: typ, score: score, total: total, playedAt: am ?? _montag);

void main() {
  group('Wochenwert', () {
    test('ohne Runde im Aufgaben-Modus gibt es keinen Wert — nicht 0 %', () {
      expect(wochenwert([], _aufgabe), isNull);
      expect(
        wochenwert([_runde(10, 10, typ: 'image_recognition')], _aufgabe),
        isNull,
      );
    });

    test('eine einzelne Runde zählt allein', () {
      expect(wochenwert([_runde(7, 10)], _aufgabe), 70);
    });

    test('von mehreren zählen die letzten ZWEI, gemittelt', () {
      final runden = [
        _runde(2, 10, am: _montag.add(const Duration(hours: 1))),
        _runde(6, 10, am: _montag.add(const Duration(days: 2))),
        _runde(9, 10, am: _montag.add(const Duration(days: 3))),
      ];
      // (60 + 90) / 2 — die schwache erste Runde fällt heraus.
      expect(wochenwert(runden, _aufgabe), 75);
    });

    test('Runden verschiedener Länge zählen als Quote, nicht als Treffer', () {
      // Jeder spielt am eigenen Bestand; 5 von 5 ist so gut wie 20 von 20.
      final runden = [
        _runde(5, 5, am: _montag.add(const Duration(hours: 1))),
        _runde(10, 20, am: _montag.add(const Duration(hours: 2))),
      ];
      expect(wochenwert(runden, _aufgabe), 75);
    });

    test('die Vorwoche zählt nicht, Montag 00:00 schon', () {
      final runden = [
        _runde(10, 10, am: _montag.subtract(const Duration(minutes: 1))),
        _runde(3, 10, am: _montag),
      ];
      expect(wochenwert(runden, _aufgabe), 30);
    });

    test('eine leere Runde (0 Fragen) wird übergangen', () {
      expect(wochenwert([_runde(0, 0)], _aufgabe), isNull);
    });

    test('gerundet auf ganze Prozent', () {
      final runden = [
        _runde(1, 3, am: _montag.add(const Duration(hours: 1))),
        _runde(1, 3, am: _montag.add(const Duration(hours: 2))),
      ];
      expect(wochenwert(runden, _aufgabe), 33);
    });
  });

  group('Wochenaufgabe', () {
    test('Karteikarten sind kein Aufgaben-Modus', () {
      expect(Lernmodus.aus('flashcards'), isNull);
      expect(Lernmodus.values.map((m) => m.schluessel).toSet(), {
        'compartment',
        'image_recognition',
        'cutaway',
        'dragdrop',
      });
    });

    test('einen unbekannten Modus vom Server zeigt die App nicht an', () {
      expect(
        Wochenaufgabe.fromJson({'woche': '2026-09-21', 'modus': 'neu'}),
        isNull,
      );
      final a =
          Wochenaufgabe.fromJson({'woche': '2026-09-21', 'modus': 'cutaway'})!;
      expect(a.modus, Lernmodus.woLiegts);
      expect(a.woche, _montag);
    });
  });

  group('Rangliste', () {
    Wertung w(String user, int wert, [DateTime? woche]) =>
        Wertung(userId: user, woche: woche ?? _montag, wert: wert);

    test('Gleichstand teilt den Platz, der nächste rückt nach (1, 1, 3)', () {
      final r = wochenRangliste(
        ['a', 'b', 'c', 'd'],
        [w('a', 70), w('b', 90), w('c', 90), w('d', 50)],
        _montag,
      );
      expect(r.map((p) => (p.userId, p.platz)), [
        ('b', 1),
        ('c', 1),
        ('a', 3),
        ('d', 4),
      ]);
    });

    test('wer noch nicht gespielt hat, steht ohne Platz dahinter', () {
      final r = wochenRangliste(['a', 'b', 'c'], [w('b', 40)], _montag);
      expect(r.map((p) => (p.userId, p.platz, p.punkte)), [
        ('b', 1, 40),
        ('a', null, null),
        ('c', null, null),
      ]);
    });

    test('die Wochenliste sieht nur ihre Woche', () {
      final vorwoche = _montag.subtract(const Duration(days: 7));
      final r = wochenRangliste(['a'], [w('a', 100, vorwoche)], _montag);
      expect(r.single.platz, isNull);
    });

    test('gesamt ist die Summe: dabei sein zählt jede Woche', () {
      final vorwoche = _montag.subtract(const Duration(days: 7));
      final r = gesamtRangliste(
        ['stetig', 'einmal'],
        [w('stetig', 60, vorwoche), w('stetig', 60), w('einmal', 100)],
      );
      expect(r.first.userId, 'stetig');
      expect(r.first.punkte, 120);
    });

    test('Ausgetretene erscheinen nicht, auch wenn noch ein Wert kommt', () {
      final r = gesamtRangliste(['a'], [w('a', 10), w('weg', 99)]);
      expect(r.map((p) => p.userId), ['a']);
    });
  });

  group('Melden', () {
    test('nur laufende Gruppen, nur mit Wert, mit Modus der Aufgabe', () async {
      final gemeldet = <(String, Lernmodus, int)>[];
      final anzahl = await meldeAlleWochenwerte(
        gruppen: [
          (id: 'laeuft', laeuft: true),
          (id: 'vorbei', laeuft: false),
          (id: 'ohneAufgabe', laeuft: true),
        ],
        aufgabe: (id) async => id == 'ohneAufgabe' ? null : _aufgabe,
        runden: (seit) async {
          expect(seit, _montag);
          return [_runde(8, 10)];
        },
        melde: (id, modus, wert) async => gemeldet.add((id, modus, wert)),
      );
      expect(anzahl, 1);
      expect(gemeldet, [('laeuft', Lernmodus.fachQuiz, 80)]);
    });

    test('ohne Runde diese Woche wird nichts gemeldet', () async {
      var aufgerufen = false;
      await meldeAlleWochenwerte(
        gruppen: [(id: 'g', laeuft: true)],
        aufgabe: (_) async => _aufgabe,
        runden: (_) async => [],
        melde: (_, _, _) async => aufgerufen = true,
      );
      expect(aufgerufen, isFalse);
    });

    test('ein Fehler bei einer Gruppe hält die nächste nicht auf', () async {
      final fehler = <String>[];
      final gemeldet = <String>[];
      final anzahl = await meldeAlleWochenwerte(
        gruppen: [(id: 'kaputt', laeuft: true), (id: 'gut', laeuft: true)],
        aufgabe: (_) async => _aufgabe,
        runden: (_) async => [_runde(5, 10)],
        melde: (id, _, _) async {
          if (id == 'kaputt') throw StateError('Wochenwechsel');
          gemeldet.add(id);
        },
        beiFehler: (id, _) => fehler.add(id),
      );
      expect(anzahl, 1);
      expect(gemeldet, ['gut']);
      expect(fehler, ['kaputt']);
    });
  });

  group('Stand auf der Startseite', () {
    test('Platz von allen, mit eigenem Wert', () {
      expect(
        standText(
          aufgabe: _aufgabe,
          mitglieder: ['ich', 'du'],
          wertungen: [
            Wertung(userId: 'du', woche: _montag, wert: 90),
            Wertung(userId: 'ich', woche: _montag, wert: 60),
          ],
          ichId: 'ich',
        ),
        'Platz 2 von 2 · 60 %',
      );
    });

    test('ohne eigene Runde eine Aufforderung statt „Platz –"', () {
      expect(
        standText(
          aufgabe: _aufgabe,
          mitglieder: ['ich'],
          wertungen: const [],
          ichId: 'ich',
        ),
        contains('noch nicht gespielt'),
      );
    });

    test('solange die Aufgabe lädt, steht nichts da', () {
      expect(
        standText(
          aufgabe: null,
          mitglieder: ['ich'],
          wertungen: const [],
          ichId: 'ich',
        ),
        isNull,
      );
    });
  });
}
