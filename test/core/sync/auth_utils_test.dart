/// auth_utils_test.dart – Nutzername→E-Mail-Mapping, Username-Validierung
/// und Initialpasswort-Generator (M7 Etappe 3).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/auth_utils.dart';

void main() {
  group('loginInputToEmail', () {
    test('Nutzername wird auf fw.local gemappt', () {
      expect(loginInputToEmail('max.m'), 'max.m@fw.local');
    });

    test('trimmt und lowercased', () {
      expect(loginInputToEmail('  Max.M  '), 'max.m@fw.local');
    });

    test('vollständige E-Mail bleibt unverändert (nur lowercase)', () {
      expect(loginInputToEmail('Admin@FW.local'), 'admin@fw.local');
      expect(
          loginInputToEmail('wer@example.org'), 'wer@example.org');
    });

    test('leere Eingabe bleibt leer', () {
      expect(loginInputToEmail('   '), '');
    });
  });

  group('isValidUsername', () {
    test('akzeptiert typische Namen', () {
      expect(isValidUsername('max.m'), isTrue);
      expect(isValidUsername('max_mustermann'), isTrue);
      expect(isValidUsername('gw-2'), isTrue);
      expect(isValidUsername('abc'), isTrue);
    });

    test('lehnt Grenzfälle ab', () {
      expect(isValidUsername('ab'), isFalse, reason: 'zu kurz');
      expect(isValidUsername('a' * 33), isFalse, reason: 'zu lang');
      expect(isValidUsername('.max'), isFalse, reason: 'Rand kein Punkt');
      expect(isValidUsername('max.'), isFalse, reason: 'Rand kein Punkt');
      expect(isValidUsername('max m'), isFalse, reason: 'Leerzeichen');
      expect(isValidUsername('max@m'), isFalse, reason: '@ verboten');
      expect(isValidUsername('Mäx'), isFalse, reason: 'Umlaut');
    });

    test('32 Zeichen sind erlaubt', () {
      expect(isValidUsername('a' * 32), isTrue);
    });
  });

  group('authErrorText', () {
    test('erkennt falsche Zugangsdaten über den Code', () {
      expect(authErrorText('Invalid login credentials',
              code: 'invalid_credentials'),
          contains('Zugangszettel'));
    });

    test('erkennt sie auch ohne Code (ältere Server)', () {
      expect(authErrorText('Invalid login credentials'),
          contains('Zugangszettel'));
    });

    test('übersetzt Sperre und Ratenbegrenzung', () {
      expect(authErrorText('x', code: 'user_banned'), contains('gesperrt'));
      expect(authErrorText('x', code: 'over_request_rate_limit'),
          contains('Zu viele Versuche'));
    });

    test('reicht Unbekanntes wörtlich durch', () {
      expect(authErrorText('Datenbank brennt'), 'Datenbank brennt');
    });
  });

  group('validateNewPassword', () {
    test('verlangt 8 Zeichen', () {
      expect(validateNewPassword('kurz12', 'kurz12'), contains('8 Zeichen'));
    });

    test('verlangt Übereinstimmung', () {
      expect(validateNewPassword('geheim123', 'geheim124'),
          contains('nicht überein'));
    });

    test('lässt ein gültiges Passwort durch', () {
      expect(validateNewPassword('geheim123', 'geheim123'), isNull);
    });

    test('meldet die Länge vor der Ungleichheit', () {
      // Sonst schickt man jemanden zweimal hintereinander zurück.
      expect(validateNewPassword('kurz', 'anders'), contains('8 Zeichen'));
    });
  });

  group('generateInitialPassword', () {
    test('Länge und Alphabet ohne verwechselbare Zeichen', () {
      for (var i = 0; i < 50; i++) {
        final pw = generateInitialPassword();
        expect(pw.length, 10);
        expect(RegExp(r'^[a-zA-Z2-9]+$').hasMatch(pw), isTrue);
        expect(pw.contains('0'), isFalse);
        expect(pw.contains('O'), isFalse);
        expect(pw.contains('1'), isFalse);
        expect(pw.contains('l'), isFalse);
        expect(pw.contains('I'), isFalse);
      }
    });

    test('liefert unterschiedliche Passwörter', () {
      expect(generateInitialPassword() == generateInitialPassword(), isFalse);
    });
  });
}
