/// bestand_gewichtung_test.dart – „Gewichten, nicht filtern".
///
/// **Die Zusicherung, die hier wirklich zählt, ist die negative:** Fragen
/// OHNE Gerätebezug — Rechtskunde, ABC-Einsatz, Löschlehre, also der weitaus
/// größte Teil des Prüfungsstoffs — dürfen durch die Gewichtung **nie**
/// verdrängt werden. Ginge das schief, würde aus einer Lern-App über Nacht
/// ein Gerätequiz, und gemerkt hätte es niemand: Die Fragen stehen ja weiter
/// in der Wissensdatenbank, sie kämen im Spiel nur nicht mehr vor.
library;

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<WissensfrageData> frage(String text, {String? geraet}) async {
    final id = await db.wissenDao.insertFrage(WissensfragenCompanion.insert(
      gebiet: 'geraetekunde',
      frage: text,
      antwortenJson: const Value('["a","b"]'),
      richtigeJson: const Value('[0]'),
      stand: const Value('freigegeben'),
      geraet: Value(geraet),
    ));
    return (await db.wissenDao.getById(id))!;
  }

  final zufall = Random(42);

  test('Fragen ohne Gerätebezug bleiben ALLE drin', () async {
    final ohne = [
      await frage('Wie lange wird der Kommandant gewählt?'),
      await frage('Was bedeutet die Ziffer 3 im Gefahrzettel?'),
      await frage('Wie ist der Löschangriff aufgebaut?'),
    ];
    final mit = [
      for (var i = 0; i < 30; i++)
        await frage('Gerätefrage $i', geraet: 'std_fremd_$i'),
    ];

    final gewaehlt =
        waehleNachBestand([...ohne, ...mit], {'std_eigen'}, zufall);

    for (final f in ohne) {
      expect(gewaehlt.map((x) => x.frage), contains(f.frage),
          reason: 'Prüfungsstoff ohne Gerätebezug darf nie wegfallen.');
    }
  });

  test('eigene Geräte kommen alle dran, fremde nur gedeckelt', () async {
    for (var i = 0; i < 9; i++) {
      await frage('Eigen $i', geraet: 'std_eigen_$i');
    }
    for (var i = 0; i < 60; i++) {
      await frage('Fremd $i', geraet: 'std_fremd_$i');
    }
    final alle = await db.wissenDao.getAll();
    final bestand = {for (var i = 0; i < 9; i++) 'std_eigen_$i'};

    final gewaehlt = waehleNachBestand(alle, bestand, zufall);
    final eigen = gewaehlt.where((f) => f.frage.startsWith('Eigen')).length;
    final fremd = gewaehlt.where((f) => f.frage.startsWith('Fremd')).length;

    expect(eigen, 9, reason: 'Der eigene Bestand kommt vollständig dran.');
    // 9 eigene ÷ 3 = 3 fremde.
    expect(fremd, 3);
  });

  test('ohne erfassten Bestand zählt ALLES als eigen', () async {
    // Sonst verlöre ausgerechnet die frisch installierte App über hundert
    // Fragen — und nach dem ersten Import wäre das Spiel plötzlich voll,
    // ohne dass jemand den Zusammenhang sähe.
    for (var i = 0; i < 12; i++) {
      await frage('Gerätefrage $i', geraet: 'std_$i');
    }
    final gewaehlt =
        waehleNachBestand(await db.wissenDao.getAll(), const {}, zufall);
    expect(gewaehlt, hasLength(12));
  });

  test('ohne eigene Geräte kommt keine fremde Gerätefrage durch', () async {
    // 0 eigene ÷ 3 = 0. Der Prüfungsstoff bleibt trotzdem vollständig — das
    // ist der Unterschied zwischen Gewichten und Abschalten.
    final ohne = await frage('Rechtsfrage ohne Gerät');
    for (var i = 0; i < 12; i++) {
      await frage('Fremd $i', geraet: 'std_fremd_$i');
    }
    final gewaehlt = waehleNachBestand(
        await db.wissenDao.getAll(), {'std_gibtesnicht'}, zufall);

    expect(gewaehlt, hasLength(1));
    expect(gewaehlt.single.frage, ohne.frage);
  });

  test('eine leere Liste bleibt leer', () {
    expect(waehleNachBestand(const [], const {'std_a'}, zufall), isEmpty);
  });
}
