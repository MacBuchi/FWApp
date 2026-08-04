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

/// Ein Nutzername-Vorschlag aus einer E-Mail-Adresse (Issue #121).
///
/// Gebraucht, wenn eine Einladung nicht zugestellt werden konnte und
/// stattdessen ein Zettel-Konto entsteht: Der lokale Teil der Adresse ist
/// die bessere Quelle als der Anzeigename — ihn hat die Person selbst
/// gewählt, und er bringt keine Umlaute und Leerzeichen mit.
///
/// Bleibt nichts Gültiges übrig, kommt der leere Text zurück. Ein
/// zurechtgebogener Vorschlag wäre schlimmer als ein leeres Feld: Der
/// Nutzername steht auf dem Zettel, den jemand abtippen muss.
String zugangsnameVorschlag(String email) {
  final sauber = email
      .split('@')
      .first
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]'), '')
      // Rand alphanumerisch, siehe _usernameRe.
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return isValidUsername(sauber) ? sauber : '';
}

/// Ist das eine echte, zustellbare Adresse — oder die interne Zettel-Form?
///
/// `<name>@fw.local` existiert nur, weil GoTrue eine E-Mail als Kennung
/// verlangt; dorthin kann niemand etwas schicken. An dieser Unterscheidung
/// hängt, ob „Passwort vergessen“ für ein Konto überhaupt in Frage kommt.
bool hatEchteMail(String email) {
  final e = email.trim().toLowerCase();
  return e.contains('@') && !e.endsWith('@$kAccountDomain');
}

/// Übersetzt einen gotrue-Fehler in einen Satz, der im Gerätehaus
/// weiterhilft. Bevorzugt den stabilen `code`; die Prüfung der Meldung bleibt
/// als Rückfallebene für ältere Server, die noch keinen Code mitschicken.
///
/// Unbekanntes wird unverändert durchgereicht statt zu „Fehler" verwischt —
/// eine Meldung, die niemand kennt, ist immer noch besser als gar keine.
String authErrorText(String message, {String? code}) {
  final m = message.toLowerCase();
  if (code == 'invalid_credentials' || m.contains('credentials')) {
    return 'Nutzername oder Passwort ist falsch. Bitte die Daten vom '
        'Zugangszettel übernehmen.';
  }
  if (code == 'email_not_confirmed' || m.contains('not confirmed')) {
    return 'Dieses Konto ist noch nicht bestätigt.';
  }
  if (code == 'over_request_rate_limit' || m.contains('rate limit')) {
    return 'Zu viele Versuche. Bitte einen Moment warten.';
  }
  if (code == 'user_banned' || m.contains('banned')) {
    return 'Dieses Konto ist gesperrt. Bitte beim Gerätewart melden.';
  }
  return message;
}

/// Prüft ein neu gewähltes Passwort. Gibt `null` zurück, wenn es passt,
/// sonst den Hinweistext.
///
/// Die Wiederholung ist Absicht: Ein Tippfehler im verdeckten Feld fällt
/// sonst erst beim nächsten Anmelden auf — und dann ist das alte Passwort
/// schon weg.
String? validateNewPassword(String password, String repeat) {
  if (password.length < 8) return 'Mindestens 8 Zeichen erforderlich.';
  if (password != repeat) return 'Die Passwörter stimmen nicht überein.';
  return null;
}

/// Erzeugt ein gut abtippbares Initialpasswort (10 Zeichen, ohne
/// verwechselbare Zeichen wie 0/O/1/l). Kryptographisch zufällig.
String generateInitialPassword({int length = 10}) {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(length, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}
