/// geraetefragen_test.dart – Der Generator, der den Fuhrpark kennt.
///
/// **Was hier wirklich geprüft wird.** Nicht, dass Fragen entstehen — das
/// sieht man. Sondern dass keine entsteht, die **zwei richtige Antworten**
/// hat. Eine erzeugte Frage mit zwei richtigen Antworten ist schlimmer als
/// gar keine Frage: Sie ist unbeantwortbar, sie sieht aber aus wie jede
/// andere, und wer sie falsch beantwortet, sucht den Fehler bei sich.
///
/// Deshalb läuft der letzte Test über den **echten ausgelieferten Katalog**
/// und nicht über ein Fixture: Die Regeln sollen für die 110 Geräte halten,
/// die tatsächlich auf den Geräten landen, nicht für drei erfundene.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/features/knowledge/data/geraetefragen.dart';

StandardCatalog katalogAus(List<Map<String, dynamic>> items) =>
    StandardCatalog.ausEintraegen(items);

Map<String, dynamic> geraet(
  String id,
  String name, {
  required List<String> funktionen,
  required List<String> verwendung,
}) =>
    {
      'id': id,
      'name': name,
      'equipment_functions': funktionen,
      'typical_use': verwendung,
      'description': '$name, Beschreibung.',
    };

void main() {
  test('aus einer eigenen Verwendung wird eine Frage mit drei Ablenkern', () {
    final k = katalogAus([
      geraet('std_a', 'Gerät A', funktionen: ['WASSER'], verwendung: ['Nur A']),
      geraet('std_b', 'Gerät B', funktionen: ['RETTUNG'], verwendung: ['Nur B']),
      geraet('std_c', 'Gerät C', funktionen: ['PSA'], verwendung: ['Nur C']),
      geraet('std_d', 'Gerät D', funktionen: ['BRAND'], verwendung: ['Nur D']),
    ]);

    final fragen = baueGeraetefragen(k);
    expect(fragen, hasLength(4));

    final a = fragen.firstWhere((f) => f.geraet == 'std_a');
    expect(a.frage, 'Wofür wird „Gerät A" typischerweise eingesetzt?');
    expect(a.richtige, 'Nur A');
    expect(a.falsche, hasLength(3));
    expect(a.falsche, isNot(contains('Nur A')));
  });

  test('ein Gerät mit gemeinsamer Funktionsgruppe liefert KEINEN Ablenker',
      () {
    // Der Kern der zweiten Regel: Zwei Lampen haben austauschbare
    // Verwendungen. Stünde die eine bei der anderen, hätte die Frage zwei
    // richtige Antworten.
    final k = katalogAus([
      geraet('std_lampe1', 'Handlampe',
          funktionen: ['BELEUCHTUNG'], verwendung: ['Ausleuchten im Innenangriff']),
      geraet('std_lampe2', 'Helmlampe',
          funktionen: ['BELEUCHTUNG'], verwendung: ['Beleuchtung am Helm']),
      geraet('std_b', 'Gerät B', funktionen: ['RETTUNG'], verwendung: ['Nur B']),
      geraet('std_c', 'Gerät C', funktionen: ['PSA'], verwendung: ['Nur C']),
      geraet('std_d', 'Gerät D', funktionen: ['BRAND'], verwendung: ['Nur D']),
    ]);

    final lampe = baueGeraetefragen(k).firstWhere(
        (f) => f.geraet == 'std_lampe1');
    expect(lampe.falsche, isNot(contains('Beleuchtung am Helm')),
        reason: 'Die andere Lampe darf keinen Ablenker stellen.');
  });

  test('eine Funktionsgruppe reicht schon, um auszuschließen', () {
    // Auch eine TEILWEISE Überschneidung schließt aus — sonst käme über die
    // zweite Gruppe wieder ein austauschbarer Satz herein.
    final k = katalogAus([
      geraet('std_a', 'Gerät A',
          funktionen: ['WASSER', 'ARMATUREN'], verwendung: ['Nur A']),
      geraet('std_ueberlappt', 'Überlappt',
          funktionen: ['ARMATUREN', 'LOGISTIK'], verwendung: ['Von Ueberlappt']),
      geraet('std_b', 'Gerät B', funktionen: ['RETTUNG'], verwendung: ['Nur B']),
      geraet('std_c', 'Gerät C', funktionen: ['PSA'], verwendung: ['Nur C']),
      geraet('std_d', 'Gerät D', funktionen: ['BRAND'], verwendung: ['Nur D']),
    ]);

    final a = baueGeraetefragen(k).firstWhere((f) => f.geraet == 'std_a');
    expect(a.falsche, isNot(contains('Von Ueberlappt')));
  });

  test('eine generische Verwendung wird weder Antwort noch Ablenker', () {
    final k = katalogAus([
      geraet('std_a', 'Gerät A',
          funktionen: ['WASSER'], verwendung: ['Jeder Einsatz', 'Nur A']),
      geraet('std_b', 'Gerät B',
          funktionen: ['RETTUNG'], verwendung: ['Jeder Einsatz', 'Nur B']),
      geraet('std_c', 'Gerät C', funktionen: ['PSA'], verwendung: ['Nur C']),
      geraet('std_d', 'Gerät D', funktionen: ['BRAND'], verwendung: ['Nur D']),
      geraet('std_e', 'Gerät E', funktionen: ['STROM'], verwendung: ['Nur E']),
    ]);

    final a = baueGeraetefragen(k).firstWhere((f) => f.geraet == 'std_a');
    expect(a.richtige, 'Nur A', reason: 'Nicht die generische Verwendung.');
    for (final f in baueGeraetefragen(k)) {
      expect(f.falsche, isNot(contains('Jeder Einsatz')));
    }
  });

  test('ohne genug fachfremde Ablenker entsteht lieber gar keine Frage', () {
    // Weglassen ist richtig: Eine Frage mit zwei Antworten wäre schlechter
    // als keine.
    final k = katalogAus([
      geraet('std_a', 'Gerät A', funktionen: ['WASSER'], verwendung: ['Nur A']),
      geraet('std_b', 'Gerät B', funktionen: ['WASSER'], verwendung: ['Nur B']),
      geraet('std_c', 'Gerät C', funktionen: ['WASSER'], verwendung: ['Nur C']),
      geraet('std_d', 'Gerät D', funktionen: ['WASSER'], verwendung: ['Nur D']),
    ]);
    expect(baueGeraetefragen(k), isEmpty);
  });

  test('zwei Läufe liefern dasselbe — sonst wüchse der Bestand bei jedem Start',
      () {
    final k = katalogAus([
      for (var i = 0; i < 8; i++)
        geraet('std_$i', 'Gerät $i',
            funktionen: ['G$i'], verwendung: ['Verwendung $i']),
    ]);
    final a = baueGeraetefragen(k);
    final b = baueGeraetefragen(k);
    expect(a.map((f) => '${f.geraet}|${f.richtige}|${f.falsche.join(",")}'),
        b.map((f) => '${f.geraet}|${f.richtige}|${f.falsche.join(",")}'));
  });

  group('gegen den echten ausgelieferten Katalog', () {
    late StandardCatalog katalog;
    late List<Geraetefrage> fragen;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      katalog = await StandardCatalog.load();
      fragen = baueGeraetefragen(katalog);
    });

    test('es entsteht ein nennenswerter Bestand', () {
      // Kein exakter Wert: Der Katalog darf wachsen, ohne diesen Test zu
      // brechen. Aber wenn er auf eine Handvoll fällt, stimmt etwas nicht.
      expect(fragen.length, greaterThan(80));
    });

    test('KEINE Frage hat einen Ablenker, der auch richtig wäre', () {
      // Die Zusicherung, um die es hier geht — gegen alle 110 echten Geräte.
      for (final f in fragen) {
        final eintrag = katalog.eintrag(f.geraet)!;
        for (final falsch in f.falsche) {
          expect(eintrag.typischeVerwendung, isNot(contains(falsch)),
              reason: '„${f.frage}" hätte mit „$falsch" zwei richtige '
                  'Antworten.');
        }
      }
    });

    test('jede Frage hat vier verschiedene Antworten', () {
      for (final f in fragen) {
        final alle = [f.richtige, ...f.falsche];
        expect(alle.toSet(), hasLength(4), reason: f.frage);
      }
    });

    test('jede Frage hängt an einem Gerät, das es im Katalog gibt', () {
      for (final f in fragen) {
        expect(katalog.contains(f.geraet), isTrue, reason: f.geraet);
      }
    });
  });
}
