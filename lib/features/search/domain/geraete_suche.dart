/// geraete_suche.dart – „Wo liegt das?" für den ganzen Fuhrpark und für ein
/// einzelnes Fahrzeug (Issue #180).
///
/// Die App konnte bis hierher nur den **Katalog** durchsuchen — welche Geräte
/// es gibt. Wo eines davon verlastet ist, stand nirgends; man klickte sich
/// Fahrzeug für Fahrzeug durch die Fächer. Genau das war der Wunsch.
///
/// Die Regeln stehen hier und nicht im Screen: Was als Treffer gilt, ist eine
/// Entscheidung mit Fällen (Umlaute, mehrere Begriffe, Kurzname), und die
/// prüft man ohne Oberfläche.
library;

import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';

/// Eine Stelle, an der ein Gerät liegt.
class Fundort {
  final int vehicleId;
  final String fahrzeug;
  final int compartmentId;

  /// Fachname samt Seite und Längsposition — dieselbe Darstellung wie im
  /// Fahrzeugmenü, im Fach-Quiz und im Party-Modus (Issue #167).
  final FachAntwort fach;

  /// Wie viele davon in diesem Fach liegen.
  final int menge;

  const Fundort({
    required this.vehicleId,
    required this.fahrzeug,
    required this.compartmentId,
    required this.fach,
    this.menge = 1,
  });
}

/// Ein Gerät mit allen Stellen, an denen es liegt.
///
/// [fundorte] darf **leer** sein: Ein Gerät kann im Katalog stehen, ohne in
/// einem Fahrzeug verlastet zu sein. Das ist kein Sonderfall, sondern der
/// Normalzustand einer Wehr, die gerade erst anfängt zu pflegen — und die
/// Suche muss es sagen können, statt „nichts gefunden" zu behaupten.
class GeraetTreffer {
  final int equipmentId;
  final String name;
  final String? kurzname;
  final String? bildPfad;
  final List<String> funktionen;
  final List<Fundort> fundorte;

  /// Was an den geführten Einheiten dieses Geräts klebt (Issue #176).
  ///
  /// Im Index und nicht in der Datenbank nachgeschlagen: Gefiltert wird bei
  /// jedem Anschlag, und eine Abfrage je Buchstabe wäre auf einem alten
  /// Diensthandy spürbar — die Begründung steht im Kopf von
  /// `geraete_suche_providers.dart` und gilt für Codes genauso.
  final List<Geraetecode> codes;

  const GeraetTreffer({
    required this.equipmentId,
    required this.name,
    this.kurzname,
    this.bildPfad,
    this.funktionen = const [],
    this.fundorte = const [],
    this.codes = const [],
  });

  /// Wie viele Stück insgesamt im Fuhrpark liegen.
  int get gesamtmenge => fundorte.fold(0, (summe, f) => summe + f.menge);

  bool get istVerlastet => fundorte.isNotEmpty;

  GeraetTreffer mitFundorten(List<Fundort> neue) => GeraetTreffer(
        equipmentId: equipmentId,
        name: name,
        kurzname: kurzname,
        bildPfad: bildPfad,
        funktionen: funktionen,
        fundorte: neue,
        codes: codes,
      );
}

/// Ein Code, der auf einer geführten Einheit dieses Geräts klebt.
class Geraetecode {
  /// Normalisiert, so wie er in der Datenbank steht.
  final String code;

  /// Kennung der Einheit („Flasche 3"), falls eine vergeben ist.
  final String? kennung;

  /// In welchem Fach DIESE Einheit liegt. `null` heißt: nicht zugeordnet
  /// — dann gilt der Fundort des Geräts.
  final int? compartmentId;

  const Geraetecode({
    required this.code,
    this.kennung,
    this.compartmentId,
  });
}

/// Das Ergebnis einer Suche, in drei Töpfe getrennt.
///
/// Die Trennung ist der eigentliche Nutzen am Fahrzeug: „nicht hier, aber im
/// LF 20, Fach G1" ist eine Antwort. „Keine Treffer" wäre eine Lüge.
class SucheErgebnis {
  /// Die eigentlichen Treffer — im gewählten Fahrzeug, oder im ganzen
  /// Fuhrpark, wenn keines gewählt ist.
  final List<GeraetTreffer> treffer;

  /// Nur bei Fahrzeug-Auswahl: passt, liegt aber in einem anderen Fahrzeug.
  final List<GeraetTreffer> woanders;

  /// Passt, ist aber in keinem Fahrzeug verlastet — steht nur im Katalog.
  final List<GeraetTreffer> nirgends;

  /// Gesetzt, wenn die Eingabe ein CODE war und getroffen hat (Issue #176).
  ///
  /// Der Unterschied zur Namenssuche ist der Punkt: Ein Name ist eine Suche
  /// mit mehreren möglichen Antworten, ein Code zeigt auf genau einen
  /// Gegenstand. Steht das hier, darf der Schirm „das ist es" sagen statt
  /// „das könnte es sein".
  final Geraetecode? codeTreffer;

  const SucheErgebnis({
    this.treffer = const [],
    this.woanders = const [],
    this.nirgends = const [],
    this.codeTreffer,
  });

  bool get istLeer =>
      treffer.isEmpty && woanders.isEmpty && nirgends.isEmpty;

  static const leer = SucheErgebnis();
}

/// Bringt Text auf die Form, in der verglichen wird.
///
/// Umlaute und ß werden aufgelöst: Wer am Handy „schlauche" tippt, sucht
/// „Schläuche" — und „schlauch" ist in „Schläuche" **keine** Teilzeichenkette,
/// die Suche fände sonst nichts. Bindestriche und Schrägstriche werden zu
/// Leerzeichen, damit „hd schlauch" den „HD-Schlauch" trifft.
String suchform(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[-/_.,]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Zerlegt die Eingabe in einzelne Begriffe.
///
/// Alle Begriffe müssen vorkommen, die Reihenfolge ist egal. Damit findet
/// „schere akku" die „Akku-Rettungsschere", was eine reine Teilzeichenkette
/// nicht täte — und der Nutzer muss den amtlichen Namen nicht auswendig
/// können.
List<String> suchbegriffe(String eingabe) =>
    suchform(eingabe).split(' ').where((b) => b.isNotEmpty).toList();

/// Passt das Gerät auf alle [begriffe]? Name **und** Kurzname zählen: In der
/// Halle sagt niemand „Hochdruckschlauch", sondern „HD".
bool passtAufBegriffe(GeraetTreffer geraet, List<String> begriffe) {
  if (begriffe.isEmpty) return false;
  final heuhaufen = suchform('${geraet.name} ${geraet.kurzname ?? ''}');
  return begriffe.every(heuhaufen.contains);
}

/// Sucht im [bestand] und trennt das Ergebnis nach [vehicleId].
///
/// [bestand] enthält jedes Gerät **einmal**, mit allen seinen Fundorten im
/// ganzen Fuhrpark — auch die Geräte ohne Fundort.
///
/// - Ohne [vehicleId] landen alle Treffer in [SucheErgebnis.treffer].
/// - Mit [vehicleId] behalten die Treffer **nur die Fundorte dieses
///   Fahrzeugs**; was ausschließlich woanders liegt, geht nach
///   [SucheErgebnis.woanders] und behält dort seine übrigen Fundorte.
///
/// Eine leere Eingabe liefert nichts. Der ganze Bestand als Antwort auf ein
/// leeres Feld wäre keine Suche, sondern die Fahrzeugansicht — die gibt es
/// schon.
SucheErgebnis sucheGeraete({
  required List<GeraetTreffer> bestand,
  required String eingabe,
  int? vehicleId,
}) {
  // ⚠️ Der Code zuerst, und zwar EXAKT. Ein Name ist eine Suche mit
  // mehreren möglichen Antworten, ein Code zeigt auf genau einen
  // Gegenstand — wer einen Aufkleber abliest, will keine Vorschlagsliste.
  //
  // Als Teilzeichenkette wäre das falsch: „FW" träfe dann jeden vergebenen
  // Code. Und dass ein getippter Gerätename zufällig ein Code ist, bleibt
  // richtig behandelt — dann IST er einer.
  final ueberCode = _codeSuche(bestand, eingabe, vehicleId);
  if (ueberCode != null) return ueberCode;

  final begriffe = suchbegriffe(eingabe);
  if (begriffe.isEmpty) return SucheErgebnis.leer;

  final treffer = <GeraetTreffer>[];
  final woanders = <GeraetTreffer>[];
  final nirgends = <GeraetTreffer>[];

  for (final geraet in bestand) {
    if (!passtAufBegriffe(geraet, begriffe)) continue;

    if (!geraet.istVerlastet) {
      nirgends.add(geraet);
      continue;
    }
    if (vehicleId == null) {
      treffer.add(geraet);
      continue;
    }
    final hier =
        geraet.fundorte.where((f) => f.vehicleId == vehicleId).toList();
    if (hier.isNotEmpty) {
      treffer.add(geraet.mitFundorten(hier));
    } else {
      woanders.add(geraet);
    }
  }

  for (final liste in [treffer, woanders, nirgends]) {
    liste.sort((a, b) => suchform(a.name).compareTo(suchform(b.name)));
  }
  return SucheErgebnis(
    treffer: treffer,
    woanders: woanders,
    nirgends: nirgends,
  );
}

/// Sucht die Eingabe als Code. `null` heißt „war keiner (oder traf nicht)" —
/// dann übernimmt die Namenssuche.
SucheErgebnis? _codeSuche(
    List<GeraetTreffer> bestand, String eingabe, int? vehicleId) {
  final gesucht = normalisiereTagCode(eingabe);
  if (gesucht == null) return null;

  for (final geraet in bestand) {
    for (final code in geraet.codes) {
      if (code.code != gesucht) continue;

      // Die Einheit ist die genauere Angabe: Dasselbe Gerät kann in zwei
      // Fächern liegen, und der Aufkleber klebt auf EINEM Gegenstand.
      // Dieselbe Regel wie beim Abhaken (`hakeCodeAb`).
      final genau = code.compartmentId == null
          ? geraet.fundorte
          : geraet.fundorte
              .where((f) => f.compartmentId == code.compartmentId)
              .toList();
      final passend = genau.isEmpty ? geraet.fundorte : genau;
      final gefunden = geraet.mitFundorten(passend);

      // Ohne Fundort: Der Gegenstand ist erfasst, aber nirgends verlastet.
      // „Nichts gefunden" wäre hier die Lüge, die die Namenssuche schon
      // einmal vermeidet.
      if (passend.isEmpty) {
        return SucheErgebnis(nirgends: [gefunden], codeTreffer: code);
      }
      if (vehicleId == null || passend.any((f) => f.vehicleId == vehicleId)) {
        return SucheErgebnis(
          treffer: [
            vehicleId == null
                ? gefunden
                : gefunden.mitFundorten(passend
                    .where((f) => f.vehicleId == vehicleId)
                    .toList()),
          ],
          codeTreffer: code,
        );
      }
      // Der Code gehört zu einem anderen Fahrzeug — genau die Auskunft, die
      // jemand braucht, der ein fremdes Gerät in der Hand hält.
      return SucheErgebnis(woanders: [gefunden], codeTreffer: code);
    }
  }
  return null;
}
