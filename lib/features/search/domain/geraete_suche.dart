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

  const GeraetTreffer({
    required this.equipmentId,
    required this.name,
    this.kurzname,
    this.bildPfad,
    this.funktionen = const [],
    this.fundorte = const [],
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
      );
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

  const SucheErgebnis({
    this.treffer = const [],
    this.woanders = const [],
    this.nirgends = const [],
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
