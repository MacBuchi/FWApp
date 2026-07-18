/// auth_utils.dart – Helfer für den Nutzername-Login (M7 Etappe 3).
///
/// Konvention: Konten heißen `<nutzername>@fw.local`; Mitglieder geben nur
/// den Nutzernamen ein, die App mappt auf die E-Mail-Form. Eine vollständige
/// E-Mail-Adresse (mit @) wird unverändert akzeptiert — so funktionieren
/// auch die historischen Konten `admin@fw.local`/`member@fw.local` und
/// künftige externe Adressen.
library;
import 'dart:math';

/// Domain-Konvention der abteilungsinternen Konten.
const kAccountDomain = 'fw.local';

/// Mappt die Login-Eingabe (Nutzername ODER E-Mail) auf die E-Mail-Form.
String loginInputToEmail(String input) {
  final trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty || trimmed.contains('@')) return trimmed;
  return '$trimmed@$kAccountDomain';
}

/// Gültige Nutzernamen: 3–32 Zeichen, a-z/0-9/Punkt/_/-, Rand alphanumerisch.
/// Muss zur USERNAME_RE der Edge Function `admin-users` passen.
final _usernameRe = RegExp(r'^[a-z0-9](?:[a-z0-9._-]{1,30})[a-z0-9]$');

bool isValidUsername(String username) =>
    _usernameRe.hasMatch(username.trim().toLowerCase());

/// Erzeugt ein gut abtippbares Initialpasswort (10 Zeichen, ohne
/// verwechselbare Zeichen wie 0/O/1/l). Kryptographisch zufällig.
String generateInitialPassword({int length = 10}) {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(length, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}
