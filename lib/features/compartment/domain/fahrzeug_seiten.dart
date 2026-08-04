/// fahrzeug_seiten.dart – Die Seiten eines Fahrzeugs (Issue #126).
///
/// Der Beladeplan soll aussehen wie das Fahrzeug: flach aufgeklappt, Dach
/// oben, dann Front, Fahrerseite, Heck, Beifahrerseite. Genau diese
/// Reihenfolge geht einmal um das Fahrzeug herum — wer davorsteht, findet
/// das Fach an derselben Stelle wieder.
///
/// Die technischen Schlüssel bleiben englisch-neutral und stabil, die
/// Beschriftung ist deutsch (dieselbe Trennung wie bei den Rollen).
///
/// **Fahrerseite/Beifahrerseite statt links/rechts** — mit Absicht: „links"
/// hängt davon ab, ob man vor oder hinter dem Fahrzeug steht, und im
/// Gerätehaus führt genau das zu Missverständnissen. Auf dem Beladeplan
/// steht es ebenso.
library;

/// Reihenfolge der Bereiche im Aufklappbild — einmal um das Fahrzeug herum.
const kFahrzeugSeiten = [
  'dach',
  'front',
  'fahrerseite',
  'heck',
  'beifahrerseite',
];

const kFahrzeugSeitenLabels = {
  'dach': 'Dach',
  'front': 'Front',
  'fahrerseite': 'Fahrerseite',
  'heck': 'Heck',
  'beifahrerseite': 'Beifahrerseite',
};

/// Anzeigename einer Seite; `null` = noch nicht zugeordnet.
String seiteAnzeigename(String? seite) =>
    kFahrzeugSeitenLabels[seite] ?? 'Ohne Seite';

/// Ist [seite] ein Wert, den auch der Server annimmt?
///
/// Zwilling zum CHECK in 20260804180000_fach_seiten.sql. Ein Wert, den nur
/// eine der beiden Seiten kennt, fällt beim Veröffentlichen auf — dann aber
/// mit dem ganzen Schnappschuss.
bool istGueltigeSeite(String? seite) =>
    seite == null || kFahrzeugSeiten.contains(seite);

/// Schlägt anhand des Fachnamens eine Seite vor — als **Vorschlag**.
///
/// ⚠️ Das ist eine Konvention, keine Tatsache: Verbreitet ist, dass
/// ungerade Geräteraum-Nummern auf der Fahrerseite liegen und gerade auf der
/// Beifahrerseite. Es gibt Wehren und Aufbauhersteller, die es anders
/// halten. Deshalb wird hier nichts still gesetzt — die Oberfläche zeigt
/// den Vorschlag an, ein Mensch bestätigt ihn, und jedes einzelne Fach lässt
/// sich danach korrigieren.
///
/// `null` heißt „kein Vorschlag" — besser nichts als geraten.
String? seiteAusName(String label) {
  final t = label.trim().toLowerCase();
  if (t.isEmpty) return null;

  // Eindeutige Wörter zuerst: Sie schlagen jede Nummerierung.
  if (t.contains('dach')) return 'dach';
  if (t.contains('front')) return 'front';
  if (t.contains('heck')) return 'heck';
  if (t.contains('fahrerseite')) {
    // ⚠️ „beifahrerseite" enthält „fahrerseite" — die längere Form muss
    // zuerst geprüft werden, sonst landet die halbe Mannschaft links.
    return t.contains('beifahrerseite') ? 'beifahrerseite' : 'fahrerseite';
  }
  // „GR" ist die übliche Kurzform für den Geräteraum hinten. Als ganzes
  // Wort, sonst trifft es auch „Gruppe" oder „Grombach".
  if (RegExp(r'(^|[^a-z])gr([^a-z]|$)').hasMatch(t)) return 'heck';

  // Geräteraum-Nummer: G1, G 2, GR3, Geräteraum 4 …
  final nummer = RegExp(r'(?:^|[^0-9])g[a-zäöüß ]*?(\d+)').firstMatch(t);
  if (nummer != null) {
    final n = int.tryParse(nummer.group(1)!);
    if (n != null && n > 0) {
      return n.isOdd ? 'fahrerseite' : 'beifahrerseite';
    }
  }
  return null;
}
