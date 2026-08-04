/// fw_avatar_test.dart – Der gezeichnete Kopf (Issue #100).
///
/// Warum hier wirklich gerastert wird statt nur Widgets zu zählen: Ein
/// Painter kann jeden Parameter entgegennehmen und trotzdem ignorieren — ein
/// `expect(find.byType(FwAvatar), findsOneWidget)` wäre grün, während alle
/// 36 Köpfe gleich aussehen. Geprüft wird deshalb das Bild: Ändert sich ein
/// Wert, müssen sich Bildpunkte ändern.
///
/// Bewusst KEIN Golden-Test: Ein hinterlegtes Referenzbild bricht bei jeder
/// Schriftart- und Renderer-Änderung und wird dann blind neu erzeugt. Die
/// Aussage „dieser Wert wirkt" hält länger als jedes Referenz-PNG.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';

const _kante = 120;
const _kanteD = 120.0;

/// Zeichnet [k] und liefert die Bildpunkte.
Future<String> _bild(AvatarKonfiguration k) async {
  final recorder = ui.PictureRecorder();
  AvatarPainter(k).paint(
    Canvas(recorder),
    const Size(_kanteD, _kanteD),
  );
  final bild = await recorder.endRecording().toImage(_kante, _kante);
  final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
  bild.dispose();
  final bytes = daten!.buffer.asUint8List();
  // Als Zeichenkette, damit ein Fehlschlag lesbar bleibt statt 57 600 Zahlen
  // auszugeben.
  return bytes.fold<int>(17, (h, b) => (h * 31 + b) & 0x7FFFFFFF).toString();
}

Future<void> _alleVerschieden(
  String was,
  Iterable<AvatarKonfiguration> koepfe,
) async {
  final gesehen = <String, AvatarKonfiguration>{};
  for (final k in koepfe) {
    final bild = await _bild(k);
    expect(
      gesehen.containsKey(bild),
      isFalse,
      reason: '$was: ${k.kodiert}\nsieht aus wie ${gesehen[bild]?.kodiert}',
    );
    gesehen[bild] = k;
  }
}

void main() {
  const standard = AvatarKonfiguration();

  test('derselbe Kopf ergibt zweimal dasselbe Bild', () async {
    expect(await _bild(standard), await _bild(standard));
  });

  test('der Kopf ist nicht bloß eine leere Fläche', () async {
    // Gegen den stillsten aller Fehlschläge: ein Painter, der gar nichts
    // zeichnet, wäre bei jedem Vergleich unten „gleich" — und der Test
    // „alle gleich" gäbe es nicht.
    final leer = await () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder);
      final bild = await recorder.endRecording().toImage(_kante, _kante);
      final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
      bild.dispose();
      return daten!.buffer
          .asUint8List()
          .fold<int>(17, (h, b) => (h * 31 + b) & 0x7FFFFFFF)
          .toString();
    }();
    expect(await _bild(standard), isNot(leer));
  });

  test('jede Kopfbedeckung sieht anders aus', () async {
    await _alleVerschieden(
      'Kopfbedeckung',
      [for (final g in kAvatarGears) standard.copyWith(gear: g)],
    );
  });

  test('jedes Augenpaar sieht anders aus', () async {
    await _alleVerschieden(
      'Augen',
      [for (final e in kAvatarEyes) standard.copyWith(eyes: e)],
    );
  });

  test('jeder Mund sieht anders aus', () async {
    await _alleVerschieden(
      'Mund',
      [for (final m in kAvatarMouths) standard.copyWith(mouth: m)],
    );
  });

  test('jeder Bart sieht anders aus', () async {
    await _alleVerschieden(
      'Bart',
      [for (final h in kAvatarHair) standard.copyWith(hair: h)],
    );
  });

  test('jede Farbe des Baukastens wirkt', () async {
    await _alleVerschieden(
      'Hintergrund',
      [for (final c in kAvatarBgs) standard.copyWith(bg: c)],
    );
    await _alleVerschieden(
      'Hautton',
      [for (final c in kAvatarSkins) standard.copyWith(skin: c)],
    );
    await _alleVerschieden(
      'Helmfarbe',
      [for (final c in kAvatarGearColors) standard.copyWith(gearColor: c)],
    );
    // Haarfarbe nur mit Haaren: Ohne Bart hat sie nichts zu färben, und ein
    // Test, der das nicht berücksichtigt, verlangt Unsinn.
    await _alleVerschieden(
      'Haarfarbe',
      [
        for (final c in kAvatarHairColors)
          standard.copyWith(hair: 'beard', hairColor: c),
      ],
    );
  });

  test('die 36 Köpfe der Mannschaft sehen alle verschieden aus', () async {
    await _alleVerschieden(
      'Vorlage',
      kAvatarVorlagen.map((v) => v.kopf),
    );
  });

  testWidgets('ohne Beschriftung bleibt der Kopf für Screenreader stumm',
      (tester) async {
    // Der Kopf steht überall NEBEN dem Namen — „Avatar, Marcus B." wäre
    // eine Wiederholung, die beim Vorlesen nur aufhält.
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [
        FwAvatar(konfiguration: standard),
        Text('Marcus B.'),
      ]),
    ));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Marcus B.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FwAvatar),
        matching: find.byType(Semantics),
        matchRoot: true,
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('mit Beschriftung ist er auffindbar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FwAvatar(konfiguration: standard, semantikLabel: 'Flecki, Dalmatiner'),
    ));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Flecki, Dalmatiner'), findsOneWidget);
    handle.dispose();
  });
}
