/// fahrzeugfragen.dart – Fahrzeugkunde aus dem eigenen Fuhrpark.
///
/// **Warum erzeugt und nicht gespeichert.** Die 107 Gerätefragen aus dem
/// Katalog sind auf jedem Gerät dieselben — stabil, korrigierbar, deshalb
/// Zeilen in der Wissensdatenbank. Der Fuhrpark ist das Gegenteil: Er gehört
/// jeder Wehr allein und ändert sich bei jedem Import. Als gespeicherte
/// Fragen würden diese hier bei jedem Umbau veralten, müssten abgeglichen
/// werden und lägen am Ende als hunderte Zeilen auf dem Server, die
/// beschreiben, was die App ohnehin weiß. Sie entstehen deshalb beim
/// Spielstart, genau wie „In welchem Fach liegt das?" seit Issue #160.
///
/// **Warum Fahrzeugkunde ausgerechnet so.** Marcus' Vorgabe (2026-08-28):
/// bewusst NICHT aus DIN 14530, sondern aus dem eigenen Fuhrpark. Eine
/// Normtabelle abzufragen lehrt die Norm; „auf welchem Wagen liegt der
/// Spreizer" lehrt den Einsatz — und das weiß nur die eigene App.
library;

import 'dart:math';

import 'package:fwapp/features/game/party/domain/party_frage.dart';

/// So viele Fahrzeuge braucht es mindestens.
///
/// Unter drei ist es keine Frage, sondern eine Münze: Bei zwei Fahrzeugen ist
/// die falsche Antwort das jeweils andere, und wer einmal daneben liegt, hat
/// beim nächsten Mal recht. Lieber keine Kategorie als eine geratene.
const kMindestFahrzeuge = 3;

/// Wie viele Antworten eine Fahrzeugfrage höchstens hat.
const kMaxFahrzeugAntworten = 4;

/// Ein Gerät, wie es für diese Fragen zählt.
class GeraetAufFahrzeug {
  final String name;
  final String? bildPfad;
  final List<String> funktionen;

  const GeraetAufFahrzeug({
    required this.name,
    this.bildPfad,
    this.funktionen = const [],
  });
}

/// Ein Fahrzeug mit dem, was auf ihm liegt.
class FahrzeugStand {
  final String name;

  /// Amtliches Kennzeichen, falls erfasst.
  final String? kennzeichen;

  final List<GeraetAufFahrzeug> geraete;

  const FahrzeugStand({
    required this.name,
    this.kennzeichen,
    this.geraete = const [],
  });
}

/// Baut die Fahrzeugfragen aus dem Bestand.
///
/// Leer, wenn der Fuhrpark zu klein ist — der Party-Modus fällt dann auf
/// seine übrigen Kategorien zurück, wie er es ohne Beladung und ohne Fotos
/// schon immer tut.
List<PartyFrage> baueFahrzeugfragen(
  List<FahrzeugStand> fahrzeuge,
  Random zufall,
) {
  if (fahrzeuge.length < kMindestFahrzeuge) return const [];

  final fragen = <PartyFrage>[
    ..._wohinGehoertDas(fahrzeuge, zufall),
    ..._welchesKennzeichen(fahrzeuge, zufall),
  ];
  return fragen;
}

/// „Auf welchem Fahrzeug liegt das?"
///
/// ⚠️ **Nur für Geräte, die es genau EINMAL im Fuhrpark gibt.** Ein
/// B-Druckschlauch liegt auf jedem Wagen; die Frage hätte dann drei richtige
/// Antworten und wäre unbeantwortbar — derselbe Fehler, den die erzeugten
/// Gerätefragen mit ihrer Ablenker-Regel vermeiden. Verglichen wird über den
/// **Namen**, nicht über die Zeilennummer: Zwei Wagen tragen denselben
/// Schlauch als zwei verschiedene Datensätze, und für die Frage ist das
/// dasselbe Gerät.
Iterable<PartyFrage> _wohinGehoertDas(
  List<FahrzeugStand> fahrzeuge,
  Random zufall,
) sync* {
  final wagenJeGeraet = <String, Set<String>>{};
  for (final f in fahrzeuge) {
    for (final g in f.geraete) {
      (wagenJeGeraet[g.name] ??= <String>{}).add(f.name);
    }
  }

  for (final f in fahrzeuge) {
    for (final g in f.geraete) {
      if (wagenJeGeraet[g.name]!.length != 1) continue;

      final andere = [
        for (final x in fahrzeuge)
          if (x.name != f.name) x.name,
      ]..shuffle(zufall);
      final antworten = [
        f.name,
        ...andere.take(kMaxFahrzeugAntworten - 1),
      ]..shuffle(zufall);

      yield PartyFrage(
        art: PartyFrageArt.fahrzeug,
        text: 'Auf welchem Fahrzeug liegt das?',
        kopfzeile: g.name,
        bildPfad: g.bildPfad,
        funktionen: g.funktionen,
        antworten: antworten.map(PartyAntwort.new).toList(),
        richtig: antworten.indexOf(f.name),
        erklaerung: '${g.name} liegt auf ${f.name} — und nur dort.',
      );
    }
  }
}

/// „Welches Kennzeichen hat …?"
///
/// Praktisches Wissen und kein Auswendiglernen um seiner selbst willen: Über
/// Funk wird das Fahrzeug mit Kennzeichen gemeldet, und wer es sucht, sucht
/// es am Tor. Nur Fahrzeuge mit erfasstem Kennzeichen, und erst ab drei —
/// sonst wäre auch das eine Münze.
Iterable<PartyFrage> _welchesKennzeichen(
  List<FahrzeugStand> fahrzeuge,
  Random zufall,
) sync* {
  final mitKennzeichen = [
    for (final f in fahrzeuge)
      if ((f.kennzeichen ?? '').trim().isNotEmpty) f,
  ];
  if (mitKennzeichen.length < kMindestFahrzeuge) return;

  // ⚠️ Zwei Fahrzeuge mit demselben Kennzeichen gibt es nicht — im echten
  // Leben nicht und im Datenbestand hoffentlich auch nicht. Ein Tippfehler
  // macht daraus aber zwei richtige Antworten, deshalb dieselbe Prüfung wie
  // oben statt eines Vertrauensvorschusses.
  final wagenJeKennzeichen = <String, int>{};
  for (final f in mitKennzeichen) {
    final k = f.kennzeichen!.trim();
    wagenJeKennzeichen[k] = (wagenJeKennzeichen[k] ?? 0) + 1;
  }

  for (final f in mitKennzeichen) {
    final richtig = f.kennzeichen!.trim();
    if (wagenJeKennzeichen[richtig] != 1) continue;

    final andere = [
      for (final x in mitKennzeichen)
        if (x.name != f.name) x.kennzeichen!.trim(),
    ]..shuffle(zufall);
    final antworten = [
      richtig,
      ...andere.take(kMaxFahrzeugAntworten - 1),
    ]..shuffle(zufall);

    yield PartyFrage(
      art: PartyFrageArt.fahrzeug,
      text: 'Welches Kennzeichen hat dieses Fahrzeug?',
      kopfzeile: f.name,
      antworten: antworten.map(PartyAntwort.new).toList(),
      richtig: antworten.indexOf(richtig),
      erklaerung: '${f.name} trägt das Kennzeichen $richtig.',
    );
  }
}
