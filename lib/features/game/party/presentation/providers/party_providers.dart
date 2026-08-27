/// party_providers.dart – Spielstand und Regeln des Party-Modus (Issue #160).
///
/// Der Modus ist **rein lokal und flüchtig** (Kategorie „lokale/ephemere
/// Features" aus CONTRIBUTING.md): kein Repository, kein Server, kein
/// Speichern über das Spielende hinaus. Der Zugriff auf die DAOs geht deshalb
/// direkt über [appDatabaseProvider].
///
/// ⚠️ **Der Party-Modus schreibt NICHTS in `QuizResults` oder
/// `LearningProgress`.** An diesem Handy antworten fremde Leute; ihre Treffer
/// gehören nicht in die Lernstatistik, den XP-Stand und die Serie des
/// Besitzers. Das ist keine Sparsamkeit, sondern der Unterschied zwischen
/// einem Spiel und einer verfälschten Lernhistorie —
/// `test/features/game/party_spiel_test.dart` hält es fest.
library;

import 'dart:math';

import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'party_providers.g.dart';

/// Ein Mitspieler. Die Punkte leben nur, solange die Partie läuft.
class PartySpieler {
  final String name;
  final int punkte;

  /// Wie oft die Runde entschieden hat: Schluck oder Aufgabe. Nur im
  /// Trinkspiel gezählt, rein zur Erheiterung am Ende.
  final int konsequenzen;

  const PartySpieler(this.name, {this.punkte = 0, this.konsequenzen = 0});

  PartySpieler mitTreffer() => PartySpieler(name, punkte: punkte + 1, konsequenzen: konsequenzen);

  PartySpieler mitKonsequenz() =>
      PartySpieler(name, punkte: punkte, konsequenzen: konsequenzen + 1);
}

/// Der Stand einer laufenden Partie.
class PartyStand {
  final List<PartySpieler> spieler;
  final List<PartyFrage> fragen;

  /// Welche Frage gerade dran ist. `>= fragen.length` heißt: vorbei.
  final int index;

  /// Gewählte Antwort der aktuellen Frage, `null` solange offen.
  final int? gewaehlt;

  /// Solange `true`, liegt der Übergabe-Schirm über der Frage. Ohne ihn läse
  /// der Vorgänger die Frage des Nachfolgers mit — und Weitergeben wäre kein
  /// Spielzug, sondern ein Versehen.
  final bool uebergabe;

  final bool trinkspiel;

  /// Die Alternativen zum Schluck, einmal beim Start gezogen. Im Stand und
  /// nicht im Provider: Ein Zug darf nicht davon abhängen, ob das Asset in
  /// diesem Moment geladen ist.
  final List<String> aufgabenTopf;

  /// Die für diese Frage gezogene Aufgabe — die Alternative zum Schluck.
  final String? aufgabe;

  const PartyStand({
    required this.spieler,
    required this.fragen,
    this.index = 0,
    this.gewaehlt,
    this.uebergabe = true,
    this.trinkspiel = false,
    this.aufgabenTopf = const [],
    this.aufgabe,
  });

  PartyStand copyWith({
    List<PartySpieler>? spieler,
    int? index,
    int? gewaehlt,
    bool? uebergabe,
    String? aufgabe,
    bool leereAntwort = false,
    bool leereAufgabe = false,
  }) =>
      PartyStand(
        spieler: spieler ?? this.spieler,
        fragen: fragen,
        index: index ?? this.index,
        gewaehlt: leereAntwort ? null : (gewaehlt ?? this.gewaehlt),
        uebergabe: uebergabe ?? this.uebergabe,
        trinkspiel: trinkspiel,
        aufgabenTopf: aufgabenTopf,
        aufgabe: leereAufgabe ? null : (aufgabe ?? this.aufgabe),
      );

  bool get beendet => index >= fragen.length;
  bool get beantwortet => gewaehlt != null;
  PartyFrage get frage => fragen[index];

  /// Reihum: Frage 0 der erste Spieler, Frage 1 der zweite, und von vorn.
  PartySpieler get amZug => spieler[index % spieler.length];

  /// Wer als Nächstes das Handy bekommt — für den Übergabe-Schirm.
  int get zugNummer => index ~/ spieler.length + 1;

  List<PartySpieler> get rangliste =>
      [...spieler]..sort((a, b) => b.punkte.compareTo(a.punkte));

  /// Wer vorn liegt — bei Gleichstand mehrere.
  ///
  /// Ohne das kürte die Rangliste still den, der zufällig zuerst eingetragen
  /// wurde. Am Tisch ist das keine Kleinigkeit: Zwei Leute mit derselben
  /// Punktzahl, und einer bekommt den Titel, weil sein Name oben stand.
  List<PartySpieler> get sieger {
    final beste = spieler.map((s) => s.punkte).reduce((a, b) => a > b ? a : b);
    return spieler.where((s) => s.punkte == beste).toList();
  }

  /// Der Platz eines Spielers: eins plus die Zahl derer mit mehr Punkten.
  /// Gleichstand teilt sich denselben Platz.
  int platz(PartySpieler s) =>
      spieler.where((x) => x.punkte > s.punkte).length + 1;
}

/// Fach- und Bildfragen aus dem eigenen Bestand.
class PartyTopf {
  final List<PartyFrage> fach;
  final List<PartyFrage> bild;

  const PartyTopf({this.fach = const [], this.bild = const []});

  bool get istLeer => fach.isEmpty && bild.isEmpty;
}

/// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
///
/// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
/// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
/// dann aus dem mitgelieferten Topf.
@riverpod
Future<PartyTopf> partyTopf(Ref ref, int? vehicleId) async {
  final db = ref.watch(appDatabaseProvider);
  final fahrzeuge = await db.vehicleDao.getAll();
  final gewaehlt = vehicleId == null
      ? fahrzeuge
      : fahrzeuge.where((v) => v.id == vehicleId).toList();

  final fach = <PartyFrage>[];
  for (final v in gewaehlt) {
    final faecher = await db.compartmentDao.getByVehicle(v.id);
    // Vier Antworten heißt: ein richtiges Fach und drei andere.
    if (faecher.length < 4) continue;
    for (final c in faecher) {
      for (final a in await db.assignmentDao.getByCompartment(c.id)) {
        final eq = await db.equipmentDao.getById(a.equipmentId);
        if (eq == null) continue;
        final falsch = faecher.where((x) => x.id != c.id).toList()..shuffle();
        // Der Index der richtigen Antwort steht über die Identität fest, nicht
        // über den Fachnamen: Zwei Fächer eines Fahrzeugs dürfen gleich
        // heißen, und ein Namensvergleich träfe dann das falsche.
        final richtigeAntwort = FachAntwort.ausFach(c);
        final antworten = [
          richtigeAntwort,
          ...falsch.take(3).map(FachAntwort.ausFach),
        ]..shuffle();
        final ort = richtigeAntwort.verortung;
        fach.add(PartyFrage(
          art: PartyFrageArt.fach,
          text: 'In welchem Fach liegt das?',
          kopfzeile: eq.name,
          // Ohne das Fahrzeug ist die Frage bei mehreren Fahrzeugen nicht zu
          // beantworten: vier Fachnamen, aber von welchem Wagen? (Issue #172)
          fahrzeug: v.name,
          bildPfad: eq.imagePath,
          funktionen: jsonToStringList(eq.equipmentFunctionsJson),
          antworten: antworten.map(PartyAntwort.ausFach).toList(),
          richtig: antworten.indexWhere((x) => identical(x, richtigeAntwort)),
          erklaerung: '${eq.name} liegt im Fach ${c.label}'
              '${ort == null ? '' : ' ($ort)'} des Fahrzeugs ${v.name}.',
        ));
      }
    }
  }

  final alle = await db.equipmentDao.getAll();
  final mitFoto = alle
      .where((e) => e.imagePath != null && e.imagePath!.isNotEmpty)
      .toList();
  final bild = <PartyFrage>[];
  if (alle.length >= 4) {
    for (final eq in mitFoto) {
      final falsch = ([...alle]..shuffle())
          .where((e) => e.id != eq.id)
          .take(3)
          .map((e) => e.name)
          .toList();
      if (falsch.length < 3) continue;
      final antworten = [eq.name, ...falsch]..shuffle();
      bild.add(PartyFrage(
        art: PartyFrageArt.bild,
        text: 'Was ist das?',
        bildPfad: eq.imagePath,
        funktionen: jsonToStringList(eq.equipmentFunctionsJson),
        antworten: antworten.map(PartyAntwort.new).toList(),
        richtig: antworten.indexOf(eq.name),
      ));
    }
  }

  return PartyTopf(fach: fach, bild: bild);
}

/// Die laufende Partie. `null` heißt: es läuft keine.
///
/// `keepAlive`, obwohl der Modus flüchtig ist: Eine autoDispose-Fassung wäre
/// weg, sobald der Party-Schirm kurz verlassen wird — eine Wischgeste nach
/// hinten würde mitten im Spiel alle Punkte löschen. Beendet wird die Partie
/// ausdrücklich über [beenden].
@Riverpod(keepAlive: true)
class PartySpiel extends _$PartySpiel {
  Random _zufall = Random();

  @override
  PartyStand? build() => null;

  /// Setzt den Zufall fest. Nur für Tests — eine Partie mit bekannter
  /// Fragenfolge lässt sich prüfen, eine zufällige nicht.
  void festerZufall(Random zufall) => _zufall = zufall;

  /// Stellt die Partie zusammen. Gibt `false` zurück, wenn keine einzige
  /// Frage zustande kam — dann bleibt der Aufbau stehen und sagt, warum.
  Future<bool> starte({
    required List<String> namen,
    required int fragenProSpieler,
    required bool trinkspiel,
    int? vehicleId,
  }) async {
    final topf = await ref.read(partyTopfProvider(vehicleId).future);
    final inhalte = await ref.read(partyInhalteProvider.future);
    // Seit Issue #174 kommt der unerwartete Topf aus der Wissensdatenbank
    // und nicht mehr direkt aus dem Asset: Nur so spielen selbst
    // eingebrachte und freigegebene Fragen mit. Das Asset ist die Aussaat,
    // die Datenbank der Bestand.
    //
    // ⚠️ Die DAO direkt, NICHT `ref.read(spielbareFragenProvider.future)`.
    // Provider sind in Riverpod 3 ab Werk auto-dispose: Ein `read` ohne
    // Zuhörer erzeugt den Provider und entsorgt ihn sofort wieder — das
    // Future wird dann NIE fertig, und der Start der Partie steht still.
    // Nachgestellt und bestätigt: mit Zuhörer kehrt es zurück, ohne nicht.
    final wissen = await ref.read(wissenDaoProvider).getSpielbare();

    final fragen = mischePartie(
      fach: topf.fach,
      bild: topf.bild,
      unerwartet: wissen
          .map((f) => wissensfrageAlsPartyFrage(f, _zufall))
          .toList(),
      anzahl: namen.length * fragenProSpieler,
      // Eine Runde ist ein Umlauf des Handys — dieselbe Länge, mit der
      // `zugNummer` rechnet. Daran hängt „eine Runde, eine Kategorie".
      proRunde: namen.length,
      zufall: _zufall,
    );
    if (fragen.isEmpty) return false;

    state = PartyStand(
      spieler: namen.map(PartySpieler.new).toList(),
      fragen: fragen,
      trinkspiel: trinkspiel,
      aufgabenTopf: inhalte.aufgaben,
    );
    return true;
  }

  /// Der Spieler am Zug hat das Handy übernommen.
  void bereit() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(uebergabe: false);
  }

  void antworte(int index) {
    final s = state;
    if (s == null || s.beendet || s.beantwortet) return;

    final richtig = s.frage.istRichtig(index);
    final spieler = [...s.spieler];
    final position = s.index % spieler.length;
    if (richtig) {
      spieler[position] = spieler[position].mitTreffer();
    } else if (s.trinkspiel) {
      spieler[position] = spieler[position].mitKonsequenz();
    }

    state = s.copyWith(
      gewaehlt: index,
      spieler: spieler,
      aufgabe: richtig || !s.trinkspiel ? null : _zieheAufgabe(s),
      leereAufgabe: richtig || !s.trinkspiel,
    );
  }

  String? _zieheAufgabe(PartyStand s) {
    if (s.aufgabenTopf.isEmpty) return null;
    return s.aufgabenTopf[_zufall.nextInt(s.aufgabenTopf.length)];
  }

  void weiter() {
    final s = state;
    if (s == null || s.beendet) return;
    state = s.copyWith(
      index: s.index + 1,
      uebergabe: true,
      leereAntwort: true,
      leereAufgabe: true,
    );
  }

  void beenden() => state = null;
}
