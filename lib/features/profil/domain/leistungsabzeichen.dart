/// leistungsabzeichen.dart – Was man sich erlernt hat, hängt am Kopf
/// (Issue #135).
///
/// ⚠️ **Bewusst keine Dienstgradabzeichen.** Der ursprüngliche Vorschlag
/// waren Schulterklappen mit Sternen und Balken. Schulterklappen bezeichnen
/// ein Amt mit echter Weisungsbefugnis — ein Truppmann, der sich im Quiz
/// drei Sterne erspielt, sieht auf einem Bildschirm in der Fahrzeughalle aus
/// wie ein Brandmeister. Dieselbe Grenze zieht das Repo schon zweimal: der
/// absichtlich künstliche Name „KreisDatenMeister" (docs/NUTZERKONZEPT.md
/// §2) und das weggelassene „AGT" am Avatar (avatar_konfiguration.dart).
///
/// Das Leistungsabzeichen dagegen gibt es wirklich, es wird für gezeigtes
/// Können verliehen und niemand verwechselt es mit einem Dienstgrad.
///
/// Die Stufe hängt am **vorhandenen Level** (home/…/dashboard_providers.dart:
/// `kXpPerLevel = 500`, XP = Punkte × 10). Absichtlich keine zweite Währung:
/// Die Rechnung steht schon sichtbar auf der Startseite, und zwei Zahlen,
/// die sich widersprechen, wären schlimmer als gar keine.
library;

import 'dart:ui' show Color;

/// Die drei Stufen — **in aufsteigender Reihenfolge**. [abzeichenFuerLevel]
/// verlässt sich darauf; [kAbzeichenAbLevel] wird darauf geprüft.
enum Leistungsabzeichen { bronze, silber, gold }

/// Ab welchem Level die Stufe hängt.
///
/// Die Zahlen kommen aus der tatsächlichen Spielzeit: Eine Runde hat
/// höchstens 20 Fragen (`compartment_quiz_screen.dart`), macht bei gutem
/// Lauf rund 150 XP — also grob drei bis vier Runden je Level.
///
/// - **Bronze ab 3** (1000 XP): etwa ein halbes Dutzend Runden. Nah genug,
///   dass es die ersten Abende trägt.
/// - **Silber ab 8** (3500 XP): rund zwei Dutzend Runden.
/// - **Gold ab 15** (7000 XP): eine echte Strecke — bei dreimal die Woche
///   ein gutes Vierteljahr. Ein Abzeichen, das man in einer Woche hat, ist
///   keines.
const kAbzeichenAbLevel = <Leistungsabzeichen, int>{
  Leistungsabzeichen.bronze: 3,
  Leistungsabzeichen.silber: 8,
  Leistungsabzeichen.gold: 15,
};

const kAbzeichenNamen = <Leistungsabzeichen, String>{
  Leistungsabzeichen.bronze: 'Bronze',
  Leistungsabzeichen.silber: 'Silber',
  Leistungsabzeichen.gold: 'Gold',
};

/// Metalltöne, nicht die Schema-Farben: Ein Abzeichen in Primärfarbe sieht
/// aus wie ein Bedienelement. Alle drei sind bewusst so dunkel gewählt, dass
/// sie auf hellem Grund noch stehen — reines Silber verschwindet dort.
const kAbzeichenFarben = <Leistungsabzeichen, Color>{
  Leistungsabzeichen.bronze: Color(0xFFAD7B4B),
  Leistungsabzeichen.silber: Color(0xFF8E9AA3),
  Leistungsabzeichen.gold: Color(0xFFD8A32B),
};

/// Die höchste erreichte Stufe, oder `null` unterhalb von Bronze.
///
/// ⚠️ **Einmal verliehen, bleibt verliehen.** Das ergibt sich hier von
/// selbst, weil XP über alle Ergebnisse summiert werden und nie kleiner
/// werden — aber es ist kein Zufall, sondern die Absicht: Ein Abzeichen, das
/// nach zwei ruhigen Wochen wieder verschwindet, bestraft genau den, der
/// zurückkommt.
Leistungsabzeichen? abzeichenFuerLevel(int level) {
  Leistungsabzeichen? erreicht;
  for (final stufe in Leistungsabzeichen.values) {
    if (level >= kAbzeichenAbLevel[stufe]!) erreicht = stufe;
  }
  return erreicht;
}

/// Die nächste noch offene Stufe samt ihrem Level, oder `null` ab Gold.
({Leistungsabzeichen stufe, int abLevel})? naechsteStufe(int level) {
  for (final stufe in Leistungsabzeichen.values) {
    final ab = kAbzeichenAbLevel[stufe]!;
    if (level < ab) return (stufe: stufe, abLevel: ab);
  }
  return null;
}

/// Der Satz, der überall danebensteht — auch für Screenreader.
String abzeichenText(Leistungsabzeichen stufe) =>
    'Leistungsabzeichen in ${kAbzeichenNamen[stufe]}';

/// Wie weit es noch bis zur nächsten Stufe ist.
///
/// Steht bewusst als Entfernung da und nicht als Fortschrittsbalken: Ein
/// Balken, der sich nach einer Runde um zwei Prozent bewegt, entmutigt mehr,
/// als er anzeigt.
String abzeichenFortschrittText(int level) {
  final naechste = naechsteStufe(level);
  if (naechste == null) return 'Höchste Stufe erreicht.';
  final fehlt = naechste.abLevel - level;
  final ziel = kAbzeichenNamen[naechste.stufe];
  return fehlt == 1
      ? 'Noch ein Level bis $ziel.'
      : 'Noch $fehlt Level bis $ziel.';
}
