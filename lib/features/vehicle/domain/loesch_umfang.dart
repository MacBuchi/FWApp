/// loesch_umfang.dart – Was beim Entfernen eines Fahrzeugs verlorengeht,
/// als Satz (Issue #127).
///
/// Eigene Datei und reine Funktion, weil der Satz die eigentliche
/// Entscheidungshilfe ist: Ein Fahrzeug zu löschen nimmt Fächer und
/// Beladeliste mit, und genau das muss vorher dastehen — samt der
/// Gegen-Auskunft, dass die Geräte selbst bleiben. Wer nur „Wirklich
/// löschen?" fragt, bekommt entweder ein zögerndes Nein oder ein
/// bereuendes Ja.
library;

/// Beugung, die im Gerätehaus niemandem auffallen soll.
String _fach(int n) => n == 1 ? '1 Fach' : '$n Fächer';
String _eintrag(int n) => n == 1 ? '1 Eintrag' : '$n Einträge';

/// Der Text der Rückfrage vor dem Entfernen von [name].
///
/// [faecher] und [beladung] sind die Zahlen aus der lokalen Datenbank —
/// beides hängt per `ON DELETE CASCADE` am Fahrzeug und geht mit.
String fahrzeugEntfernenText({
  required String name,
  required int faecher,
  required int beladung,
}) {
  final teile = <String>[
    if (faecher > 0) _fach(faecher),
    if (beladung > 0) '${_eintrag(beladung)} der Beladeliste',
  ];
  final kopf = teile.isEmpty
      ? '„$name" wird entfernt. Es hängt nichts daran.'
      : '„$name" wird entfernt — mit ${teile.join(' und ')}.';

  // Die wichtigste Zeile ist die zweite: Ohne sie liest sich das Löschen
  // eines Fahrzeugs wie das Löschen des halben Bestands.
  final rest = faecher > 0 || beladung > 0
      ? ' Die Geräte selbst bleiben im Bestand — nur ihre Zuordnung zu '
          'diesem Fahrzeug entfällt. Prüfpflichtige Exemplare behalten ihre '
          'Prüfhistorie, verlieren aber ihren Standort.'
      : '';

  return '$kopf$rest Rückgängig machen lässt sich das nicht.';
}
