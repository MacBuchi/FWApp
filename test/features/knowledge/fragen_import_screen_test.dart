/// fragen_import_screen_test.dart – Was nach dem Einlesen auf dem Schirm
/// steht.
///
/// Die Dateiauswahl ist nativ und im Prüfstand nicht zu bedienen — geprüft
/// wird deshalb der Teil, an dem sich jemand beim Nachbessern orientiert:
/// **die Zeilennummern, die Doppelten und die unbekannten Spalten.** Stimmt
/// eine Zeilennummer nicht, sucht man in der falschen Zeile, und die Datei
/// sieht dabei fehlerfrei aus.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/knowledge/data/fragen_import.dart';
import 'package:fwapp/features/knowledge/presentation/screens/fragen_import_screen.dart';

void main() {
  const kopf = [
    'frage',
    'gebiet',
    'antwort1',
    'antwort2',
    'antwort3',
    'richtig',
  ];

  List<String> zeile(String frage, String richtig) =>
      [frage, 'geraetekunde', 'A', 'B', 'C', richtig];

  Future<FrageImportErgebnis> lese(List<List<String>> rows,
          {Set<String> vorhanden = const {}}) async =>
      leseFragen(ImportTable(name: 'fragen.csv', rows: rows),
          vorhandeneFragen: vorhanden);

  Future<void> zeige(WidgetTester tester, FrageImportErgebnis e) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FragenImportBefund(
            ergebnis: e,
            dateiname: 'fragen.csv',
            aufUebernehmen: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('zählt, was bereit ist', (tester) async {
    await zeige(
        tester,
        await lese([
          kopf,
          zeile('Erste Frage mit Zeichen?', '1'),
          zeile('Zweite Frage mit Zeichen?', '2'),
        ]));

    expect(find.textContaining('2 Fragen bereit'), findsOneWidget);
    expect(find.text('2 übernehmen'), findsOneWidget);
  });

  testWidgets('eine einzelne Frage heißt „Frage", nicht „Fragen"',
      (tester) async {
    await zeige(tester, await lese([kopf, zeile('Nur eine Frage?', '1')]));
    expect(find.textContaining('1 Frage bereit'), findsOneWidget);
  });

  testWidgets('nennt die Zeilennummer aus der Tabellenkalkulation',
      (tester) async {
    // Kopfzeile ist 1, die kaputte Zeile hier also 3.
    await zeige(
        tester,
        await lese([
          kopf,
          zeile('Gute Frage mit Zeichen?', '1'),
          zeile('Kaputte Frage mit Zeichen?', '99'),
        ]));

    expect(find.text('Zeilen zum Nachbessern'), findsOneWidget);
    expect(find.text('Zeile 3'), findsOneWidget);
  });

  testWidgets('zeigt Doppelte getrennt von Fehlern', (tester) async {
    await zeige(
      tester,
      await lese(
        [kopf, zeile('Schon vorhanden?', '1')],
        vorhanden: {schluesselFuer('Schon vorhanden?')},
      ),
    );

    expect(find.text('Schon im Bestand'), findsOneWidget);
    expect(find.text('Schon vorhanden?'), findsOneWidget);
    // Doppelte sind kein Fehler — sie stehen in einem eigenen Block.
    expect(find.text('Zeilen zum Nachbessern'), findsNothing);
    expect(find.textContaining('0 Fragen bereit'), findsOneWidget);
  });

  testWidgets('meldet unbekannte Spalten beim Namen', (tester) async {
    await zeige(
        tester,
        await lese([
          [...kopf, 'Erklaerungg'],
          [...zeile('Eine Frage mit Zeichen?', '1'), 'vertippt'],
        ]));

    expect(find.textContaining('Erklaerungg'), findsOneWidget);
  });

  testWidgets('ohne übernehmbare Zeile gibt es keinen Knopf', (tester) async {
    await zeige(
        tester, await lese([kopf, zeile('Kaputte Frage mit Zeichen?', '99')]));
    expect(find.textContaining('übernehmen'), findsNothing);
  });

  testWidgets('der Knopf reicht genau die übernehmbaren Zeilen weiter',
      (tester) async {
    List<FrageImportZeile>? bekommen;
    final e = await lese([
      kopf,
      zeile('Gute Frage mit Zeichen?', '1'),
      zeile('Kaputte Frage mit Zeichen?', '99'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FragenImportBefund(
            ergebnis: e,
            dateiname: 'fragen.csv',
            aufUebernehmen: (z) => bekommen = z,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 übernehmen'));
    await tester.pumpAndSettle();

    expect(bekommen, hasLength(1));
    expect(bekommen!.single.frage!.frage, 'Gute Frage mit Zeichen?');
  });
}
