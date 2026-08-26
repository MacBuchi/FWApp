/// party_spiel_test.dart – Die Regeln einer Partie (Issue #160).
///
/// Der schärfste Test steht unten: **Der Party-Modus schreibt nichts in die
/// Lernstatistik.** An diesem Handy antworten fremde Leute, und ihre Treffer
/// dürfen weder XP noch Serie noch Ergebnisliste des Besitzers verändern.
library;

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';
import 'package:fwapp/features/game/party/presentation/providers/party_providers.dart';

import '../../helpers/test_database.dart';

/// Ein überschaubarer Topf: Die richtige Antwort heißt immer „Richtig".
final testInhalte = PartyInhalte(
  fragen: List.generate(
      12,
      (i) => UnerwarteteFrage(
            frage: 'Testfrage $i',
            antworten: const ['Richtig', 'Falsch A', 'Falsch B'],
            richtig: 0,
            kategorie: kKategorieWissen,
          )),
  aufgaben: const ['Zehn Liegestütze'],
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Ein Fahrzeug mit vier Fächern und einem verorteten Gerät — genug für
  /// eine Fach-Frage.
  Future<void> seedBestand() async {
    final vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
    final faecher = <int>[];
    for (final (label, seite) in const [
      ('G1', 'fahrerseite'),
      ('G2', 'beifahrerseite'),
      ('G3', 'fahrerseite'),
      ('G4', 'beifahrerseite'),
    ]) {
      faecher.add(await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
            vehicleId: vehicleId, label: label, seite: Value(seite)),
      ));
    }
    final geraet = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Spreizer'));
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: faecher.first, equipmentId: geraet));
  }

  ProviderContainer container({PartyInhalte? inhalte}) {
    // ProviderContainer.test() statt des blanken Konstruktors: Riverpod 3
    // hängt den Container damit an den Test und räumt ihn selbst ab. Der
    // blanke Konstruktor scheiterte hier reproduzierbar mit
    // „_listenedElement was called on null", sobald ein Notifier über einen
    // await hinweg gelesen wird.
    final c = ProviderContainer.test(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      partyInhalteProvider.overrideWith((ref) async => inhalte ?? testInhalte),
    ]);
    c.read(partySpielProvider.notifier).festerZufall(Random(160));
    return c;
  }

  /// Der Stand der laufenden Partie.
  ///
  /// ⚠️ **Erst lesen, dann `!`** — niemals `return c.read(partySpielProvider)!`
  /// direkt. Steht das `!` in einem Rumpf mit deklariertem Rückgabetyp
  /// `PartyStand`, leitet Dart daraus `read<PartyStand>` statt
  /// `read<PartyStand?>` ab. Riverpod 3 fängt den Typfehler nicht ab: Der
  /// `impl`-Getter in `provider_subscription.dart` ist ein nicht
  /// erschöpfendes `switch`, gibt still `null` zurück, und der Test stirbt mit
  /// „The getter '_listenedElement' was called on null" — einer Meldung, die
  /// nichts mit der Ursache zu tun hat. Zwei Zeilen statt einer, und es ist
  /// weg.
  PartyStand stand(ProviderContainer c) {
    final s = c.read(partySpielProvider);
    return s!;
  }

  Future<PartyStand> starte(
    ProviderContainer c, {
    List<String> namen = const ['Anna', 'Ben'],
    int fragenProSpieler = 3,
    bool trinkspiel = false,
  }) async {
    final klappt = await c.read(partySpielProvider.notifier).starte(
        namen: namen,
        fragenProSpieler: fragenProSpieler,
        trinkspiel: trinkspiel);
    expect(klappt, isTrue);
    return stand(c);
  }

  /// Beantwortet die laufende Frage; [richtig] entscheidet, wie.
  void antworte(ProviderContainer c, {required bool richtig}) {
    final frage = stand(c).frage;
    final index = richtig
        ? frage.richtig
        : List.generate(frage.antworten.length, (i) => i)
            .firstWhere((i) => i != frage.richtig);
    c.read(partySpielProvider.notifier).antworte(index);
  }

  test('vor dem Start läuft keine Partie', () {
    expect(container().read(partySpielProvider), isNull);
  });

  test('Zahl der Fragen: Spieler mal Fragen je Spieler', () async {
    final c = container();
    final stand = await starte(c,
        namen: const ['Anna', 'Ben', 'Cem'], fragenProSpieler: 3);
    expect(stand.fragen, hasLength(9));
  });

  test('es geht reihum und jeder kommt gleich oft dran', () async {
    final c = container();
    await starte(c, fragenProSpieler: 2);
    final amZug = <String>[];
    while (!stand(c).beendet) {
      final notifier = c.read(partySpielProvider.notifier);
      amZug.add(stand(c).amZug.name);
      notifier.bereit();
      antworte(c, richtig: true);
      notifier.weiter();
    }
    expect(amZug, ['Anna', 'Ben', 'Anna', 'Ben']);
  });

  test('vor jeder Frage steht die Übergabe', () async {
    final c = container();
    await starte(c);
    expect(stand(c).uebergabe, isTrue);
    c.read(partySpielProvider.notifier).bereit();
    expect(stand(c).uebergabe, isFalse);
    antworte(c, richtig: true);
    c.read(partySpielProvider.notifier).weiter();
    expect(stand(c).uebergabe, isTrue);
  });

  test('richtig gibt einen Punkt, falsch nicht', () async {
    final c = container();
    await starte(c);
    c.read(partySpielProvider.notifier).bereit();
    antworte(c, richtig: true);
    expect(stand(c).spieler.first.punkte, 1);

    c.read(partySpielProvider.notifier).weiter();
    c.read(partySpielProvider.notifier).bereit();
    antworte(c, richtig: false);
    expect(stand(c).spieler[1].punkte, 0);
  });

  test('eine zweite Antwort auf dieselbe Frage zählt nicht', () async {
    final c = container();
    await starte(c);
    c.read(partySpielProvider.notifier).bereit();
    antworte(c, richtig: true);
    antworte(c, richtig: true);
    expect(stand(c).spieler.first.punkte, 1);
  });

  group('Trinkspiel', () {
    test('ohne Trinkspiel gibt es keine Konsequenz', () async {
      final c = container();
      await starte(c, trinkspiel: false);
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: false);
      final s = stand(c);
      expect(s.aufgabe, isNull);
      expect(s.spieler.first.konsequenzen, 0);
    });

    test('falsche Antwort zieht eine Aufgabe als Alternative', () async {
      final c = container();
      await starte(c, trinkspiel: true);
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: false);
      final s = stand(c);
      expect(s.aufgabe, 'Zehn Liegestütze');
      expect(s.spieler.first.konsequenzen, 1);
    });

    test('richtige Antwort bleibt folgenlos', () async {
      final c = container();
      await starte(c, trinkspiel: true);
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: true);
      expect(stand(c).aufgabe, isNull);
    });

    test('leerer Aufgabentopf lässt das Spiel weiterlaufen', () async {
      final c = container(
          inhalte: PartyInhalte(fragen: testInhalte.fragen, aufgaben: const []));
      await starte(c, trinkspiel: true);
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: false);
      expect(stand(c).aufgabe, isNull);
    });

    test('die nächste Frage erbt die Aufgabe nicht', () async {
      final c = container();
      await starte(c, trinkspiel: true);
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: false);
      c.read(partySpielProvider.notifier).weiter();
      expect(stand(c).aufgabe, isNull);
      expect(stand(c).gewaehlt, isNull);
    });
  });

  test('mit Bestand kommen auch Fach-Fragen vor', () async {
    await seedBestand();
    final c = container();
    final stand = await starte(c, fragenProSpieler: 8);
    expect(stand.fragen.where((f) => f.art == PartyFrageArt.fach), isNotEmpty);
  });

  test('jede Fach-Frage nennt ihr Fahrzeug (Issue #172)', () async {
    // Der gemeldete Fehler: „Es ist nicht vermerkt, um welches Fahrzeug es
    // geht." Zur Wahl stehen vier Fachnamen — ohne den Wagen dazu ist die
    // Frage nicht zu beantworten, sondern zu raten. Genannt wurde er nur in
    // der Auflösung, also nach der Antwort.
    await seedBestand();
    final c = container();
    final stand = await starte(c, fragenProSpieler: 8);
    final fachFragen =
        stand.fragen.where((f) => f.art == PartyFrageArt.fach).toList();
    expect(fachFragen, isNotEmpty);
    for (final f in fachFragen) {
      expect(f.fahrzeug, 'HLF 20');
    }
    // Unerwartete Fragen haben kein Fahrzeug — dort wäre die Angabe falsch.
    expect(
        stand.fragen
            .where((f) => f.art == PartyFrageArt.unerwartet)
            .every((f) => f.fahrzeug == null),
        isTrue);
  });

  test('eine Runde stellt nur eine Art Frage (Issue #172)', () async {
    // Der zweite Punkt aus dem Issue: „sinnvoller, in einer Runde jeweils
    // bei einer Kategorie zu bleiben." Eine Runde ist ein Umlauf des Handys
    // — dieselbe Länge, mit der `zugNummer` rechnet.
    await seedBestand();
    final c = container();
    const namen = ['Anna', 'Ben', 'Cem'];
    final stand = await starte(c, namen: namen, fragenProSpieler: 3);
    for (var start = 0; start < stand.fragen.length; start += namen.length) {
      final runde = stand.fragen
          .sublist(start, min(start + namen.length, stand.fragen.length));
      expect(runde.map((f) => f.art).toSet(), hasLength(1),
          reason: 'Runde ab $start ist gemischt');
    }
  });

  test('ohne Bestand und ohne Topf startet die Partie gar nicht', () async {
    // Kein Fahrzeug, kein Asset — dann ist ein Start ohne Fragen ehrlicher
    // als ein leerer Spielschirm.
    final c = container(inhalte: PartyInhalte.leer);
    final klappt = await c
        .read(partySpielProvider.notifier)
        .starte(namen: const ['Anna', 'Ben'], fragenProSpieler: 3, trinkspiel: false);
    expect(klappt, isFalse);
    expect(c.read(partySpielProvider), isNull);
  });

  group('Rangliste', () {
    test('der mit den meisten Punkten steht auf Platz 1', () async {
      final c = container();
      await starte(c, fragenProSpieler: 1);
      // Anna trifft, Ben nicht.
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: true);
      c.read(partySpielProvider.notifier).weiter();
      c.read(partySpielProvider.notifier).bereit();
      antworte(c, richtig: false);

      final s = stand(c);
      expect(s.sieger.map((p) => p.name), ['Anna']);
      expect(s.platz(s.spieler[0]), 1);
      expect(s.platz(s.spieler[1]), 2);
      expect(s.rangliste.first.name, 'Anna');
    });

    test('Gleichstand kürt niemanden über die Listenreihenfolge', () async {
      // Der Fall, der beim Durchklicken auffiel: Beide 1 Punkt, und trotzdem
      // stand „Sieger: Anna" da — allein weil sie zuerst eingetragen wurde.
      final c = container();
      await starte(c, fragenProSpieler: 1);
      for (var i = 0; i < 2; i++) {
        c.read(partySpielProvider.notifier).bereit();
        antworte(c, richtig: true);
        c.read(partySpielProvider.notifier).weiter();
      }

      final s = stand(c);
      expect(s.sieger.map((p) => p.name), ['Anna', 'Ben']);
      expect(s.platz(s.spieler[0]), 1);
      expect(s.platz(s.spieler[1]), 1);
    });

    test('gleiche Punkte teilen den Platz, der nächste rutscht nicht auf',
        () async {
      final c = container(inhalte: testInhalte);
      await starte(c, namen: const ['Anna', 'Ben', 'Cem'], fragenProSpieler: 1);
      // Anna und Ben treffen, Cem nicht.
      for (final treffer in [true, true, false]) {
        c.read(partySpielProvider.notifier).bereit();
        antworte(c, richtig: treffer);
        c.read(partySpielProvider.notifier).weiter();
      }

      final s = stand(c);
      expect(s.platz(s.spieler[0]), 1);
      expect(s.platz(s.spieler[1]), 1);
      // Nicht Platz 2: Vor Cem liegen zwei.
      expect(s.platz(s.spieler[2]), 3);
    });
  });

  test('Abbrechen räumt die Partie weg', () async {
    final c = container();
    await starte(c);
    c.read(partySpielProvider.notifier).beenden();
    expect(c.read(partySpielProvider), isNull);
  });

  test('⚠️ eine ganze Partie hinterlässt KEINE Lernstatistik', () async {
    // Fremde Antworten auf diesem Handy dürfen die Historie des Besitzers
    // nicht anfassen — sonst ist der eigene Lernstand nach einem Abend im
    // Gerätehaus wertlos.
    await seedBestand();
    final c = container();
    await starte(c, fragenProSpieler: 4);
    while (!stand(c).beendet) {
      final notifier = c.read(partySpielProvider.notifier);
      notifier.bereit();
      antworte(c, richtig: true);
      notifier.weiter();
    }

    expect(await db.quizDao.getRecent(), isEmpty);
    expect(await db.select(db.learningProgress).get(), isEmpty);
  });
}
