/// dubletten_dialog_test.dart – Die Rückfrage vor dem Veröffentlichen (#67).
///
/// Der Punkt dieses Tests ist die **Voreinstellung**: Zusammenführen löscht
/// einen Eintrag, und ein Dialog, der bei Unachtsamkeit löscht, ist keine
/// Hilfe. Wer nur durchtippt, darf nichts verlieren.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/dubletten.dart';
import 'package:fwapp/core/sync/dubletten_dialog.dart';

EquipmentItemData _geraet(int id, String name, {bool neu = true}) =>
    EquipmentItemData(
      id: id,
      name: name,
      equipmentFunctionsJson: '[]',
      deploymentScenariosJson: '[]',
      description: '',
      isCustom: false,
      extraAttributesJson: '{}',
      trainingQuestionsJson: '[]',
      typicalUseJson: '[]',
      updatedAt: DateTime(2026),
      typeDirty: false,
      dirty: neu,
    );

final _paar = Dublette(
  art: DublettenArt.position,
  behalten: _geraet(1, 'Strahlrohr C', neu: false),
  aufgeben: _geraet(2, 'C-Strahlrohr'),
  aehnlichkeit: 0.9,
  ort: 'HLF 20 · G1',
);

void main() {
  /// Öffnet den Dialog. Das Ergebnis landet in [ergebnisse], damit die
  /// Tests, die es brauchen, es lesen können.
  final ergebnisse = <String, List<Zusammenfuehrung>?>{};

  Future<void> zeige(
    WidgetTester tester,
    List<Dublette> dubletten, {
    bool verschachtelt = false,
  }) async {
    final knopf = Builder(
      builder:
          (context) => ElevatedButton(
            onPressed:
                () async =>
                    ergebnisse['x'] = await frageNachDubletten(
                      context,
                      dubletten,
                    ),
            child: const Text('los'),
          ),
    );
    await tester.pumpWidget(
      MaterialApp(
        // ⚠️ Der verschachtelte Navigator ist kein Schnörkel: Die echte App
        // hängt unter einer ShellRoute, und genau daran ist in v1.6.0 ein
        // Dialog zerbrochen, dessen flach geprüfte Fassung grün war.
        home:
            verschachtelt
                ? Navigator(
                  onGenerateRoute:
                      (s) => MaterialPageRoute(
                        builder: (_) => Scaffold(body: knopf),
                      ),
                )
                : Scaffold(body: knopf),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
  }

  testWidgets('⚠️ wer nur bestätigt, führt NICHTS zusammen', (tester) async {
    await zeige(tester, [_paar]);

    expect(find.text('„Strahlrohr C" und „C-Strahlrohr"'), findsOneWidget);
    expect(
      find.text('Alles verschieden, veröffentlichen'),
      findsOneWidget,
      reason: 'Der Knopf sagt, was er tut — hier: nichts löschen.',
    );

    await tester.tap(find.text('Alles verschieden, veröffentlichen'));
    await tester.pumpAndSettle();
  });

  testWidgets('„Dasselbe" liefert das Paar zurück', (tester) async {
    await zeige(tester, [_paar]);

    await tester.tap(find.text('Dasselbe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 zusammenführen und veröffentlichen'));
    await tester.pumpAndSettle();

    expect(ergebnisse['x'], hasLength(1));
    expect(
      ergebnisse['x']!.single.behalten,
      1,
      reason: 'Voreingestellt bleibt der bereits veröffentlichte Eintrag.',
    );
    expect(ergebnisse['x']!.single.aufgeben, 2);
  });

  testWidgets('der Nutzer kann den anderen Namen behalten', (tester) async {
    await zeige(tester, [_paar]);

    await tester.tap(find.text('Dasselbe'));
    await tester.pumpAndSettle();
    // Erst jetzt steht die Auswahl da — vorher hätte sie keine Folge.
    expect(find.text('„C-Strahlrohr"'), findsOneWidget);
    await tester.tap(find.text('„C-Strahlrohr"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 zusammenführen und veröffentlichen'));
    await tester.pumpAndSettle();

    expect(ergebnisse['x']!.single.behalten, 2);
    expect(ergebnisse['x']!.single.aufgeben, 1);
  });

  testWidgets('⚠️ Abbrechen heißt: gar nicht veröffentlichen', (tester) async {
    await zeige(tester, [_paar]);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(
      ergebnisse['x'],
      isNull,
      reason:
          'null trennt „nichts zusammenführen" von „gar nicht erst '
          'hochladen".',
    );
  });

  testWidgets('beide Gruppen werden getrennt überschrieben', (tester) async {
    await zeige(tester, [
      _paar,
      Dublette(
        art: DublettenArt.katalog,
        behalten: _geraet(3, 'Schlauchhalter', neu: false),
        aufgeben: _geraet(4, 'Schlauchhalterung'),
        aehnlichkeit: 0.85,
        ort: 'G1 und Heck',
      ),
    ]);

    expect(find.text('Im selben Geräteraum'), findsOneWidget);
    expect(find.text('Ähnliche Namen im Bestand'), findsOneWidget);
    expect(find.text('HLF 20 · G1'), findsOneWidget);
    expect(find.text('G1 und Heck'), findsOneWidget);

    await tester.tap(find.text('Alles verschieden, veröffentlichen'));
    await tester.pumpAndSettle();
  });

  testWidgets('⚠️ auch unter einem verschachtelten Navigator', (tester) async {
    // Der Fall aus v1.6.0: flach geprüft grün, in der echten App (ShellRoute)
    // riss derselbe Dialog den Bildschirm weg.
    await zeige(tester, [_paar], verschachtelt: true);

    expect(find.text('Ist das zweimal dasselbe?'), findsOneWidget);
    await tester.tap(find.text('Alles verschieden, veröffentlichen'));
    await tester.pumpAndSettle();

    expect(ergebnisse['x'], isEmpty);
    expect(
      find.text('los'),
      findsOneWidget,
      reason: 'Der Bildschirm darunter muss stehen bleiben.',
    );
  });
}
