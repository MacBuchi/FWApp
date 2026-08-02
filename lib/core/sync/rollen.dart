/// rollen.dart – Anzeigenamen des Nutzerkonzepts (docs/NUTZERKONZEPT.md §2).
///
/// Die technischen Schlüssel ('admin' | 'geraetewart' | 'member') bleiben
/// stabil — ein Anzeigetext kostet nichts, ein DB-Enum kostet eine Migration
/// samt Alt-Client-Choreografie. Übersetzt wird deshalb NUR hier.
library;

/// Anzeigename einer Rolle.
///
/// [kommandant] überstimmt alles — der Feuerwehrkommandant ist keine
/// Mitgliedschaftsrolle, sondern eine Gesamtwehr-Stellung. [echteMail]
/// trennt Truppführer (Konto mit eigener Mail) von Truppmann
/// (Zettel-Konto) — dieselbe Grenze wie `hatEchteMail()`.
String rolleAnzeigename(
  String? role, {
  bool kommandant = false,
  bool echteMail = false,
}) {
  if (kommandant) return 'Feuerwehrkommandant';
  switch (role) {
    case 'admin':
      return 'Abteilungskommandant';
    case 'geraetewart':
      return 'Gerätewart';
    default:
      return echteMail ? 'Truppführer' : 'Truppmann';
  }
}

/// Unter welchem Titel darf der Angemeldete IN EINER BESTIMMTEN Abteilung
/// schreiben? `null` heißt: nur Lesezugriff.
///
/// Spiegelt `canEditProvider` für eine frei gewählte Abteilung — der Picker
/// muss die Rechte aller Abteilungen nebeneinander zeigen, nicht nur die der
/// gerade angezeigten. Seit Stufe ① ist das nicht mehr aus der Heimat
/// ableitbar: Eine Schwester-Abteilung, in der man Gerätewart ist, ist
/// beschreibbar, und der Feuerwehrkommandant schreibt in der ganzen
/// Gesamtwehr.
///
/// [mitgliedschaften] `null` = Alt-Server ohne Mitgliedschaften; dann ist die
/// Frage von hier aus nicht beantwortbar und der Aufrufer bleibt bei der
/// alten Regel „Heimat schreibend, Schwester lesend".
String? schreibrolleInAbteilung({
  required String abteilungId,
  required String? gesamtwehrId,
  required Map<String, String>? mitgliedschaften,
  required Set<String>? kommandierteGesamtwehren,
}) {
  if (mitgliedschaften == null) return null;
  if (gesamtwehrId != null &&
      (kommandierteGesamtwehren?.contains(gesamtwehrId) ?? false)) {
    return rolleAnzeigename(null, kommandant: true);
  }
  final rolle = mitgliedschaften[abteilungId];
  if (rolle == 'admin' || rolle == 'geraetewart') {
    return rolleAnzeigename(rolle);
  }
  return null;
}
