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
