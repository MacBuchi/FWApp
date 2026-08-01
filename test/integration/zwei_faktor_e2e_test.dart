/// zwei_faktor_e2e_test.dart – TOTP gegen den echten Stack (Issue #57
/// Phase 4, Etappe 3).
///
/// Warum das kein Widget-Test sein kann: Ob ein Faktor wirklich greift,
/// entscheidet GoTrue — Einrichten, Bestätigen, die Stufe der Sitzung
/// (aal1 → aal2) und das Zurücksetzen durch einen Admin. Ein Fake würde
/// genau die Mechanik nachbauen, die zu prüfen ist.
///
/// Der Test erzeugt die Sechsstelligen selbst (RFC 6238) — in der App
/// kommen sie aus der Authenticator-App des Nutzers.
///
/// Voraussetzung: `supabase start`. Ohne Stack überspringt sich die Datei.
library;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const _mail = 'totp.probe@example.org';
const _passwort = 'test1234';

Future<bool> _erreichbar(String url) async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final r = await (await c.getUrl(Uri.parse(url))).close();
    await r.drain<void>();
    c.close();
    return r.statusCode < 500;
  } catch (_) {
    return false;
  }
}

Future<String> _admin(String method, String pfad, {Object? body}) async {
  final c = HttpClient();
  final req = await c.openUrl(method, Uri.parse('$_url$pfad'));
  req.headers.set('apikey', _serviceRoleKey);
  req.headers.set('Authorization', 'Bearer $_serviceRoleKey');
  req.headers.contentType = ContentType.json;
  if (body != null) req.write(jsonEncode(body));
  final resp = await req.close();
  final text = await resp.transform(utf8.decoder).join();
  c.close();
  return text;
}

/// Base32 (RFC 4648, ohne Padding) — so kodiert GoTrue den TOTP-Schlüssel.
Uint8List _base32(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var bits = 0, wert = 0;
  final out = <int>[];
  for (final z in input.toUpperCase().replaceAll('=', '').split('')) {
    final i = alphabet.indexOf(z);
    if (i < 0) continue;
    wert = (wert << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.add((wert >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}

/// Sechsstelliger TOTP-Code nach RFC 6238 (SHA1, 30-Sekunden-Fenster).
String _totp(String secret, {int? zeitschritt}) {
  final schritt =
      zeitschritt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ 30;
  final zaehler = ByteData(8)..setUint64(0, schritt);
  final hmac = Hmac(sha1, _base32(secret)).convert(zaehler.buffer.asUint8List());
  final d = hmac.bytes;
  final offset = d[d.length - 1] & 0x0f;
  final code = ((d[offset] & 0x7f) << 24) |
      ((d[offset + 1] & 0xff) << 16) |
      ((d[offset + 2] & 0xff) << 8) |
      (d[offset + 3] & 0xff);
  return (code % 1000000).toString().padLeft(6, '0');
}

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health')) {
    test('zwei-faktor e2e', () {},
        skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).');
    return;
  }

  late SupabaseClient client;
  String? userId;

  setUpAll(() async {
    client = SupabaseClient(_url, _anonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final angelegt = await _admin('POST', '/auth/v1/admin/users', body: {
      'email': _mail,
      'password': _passwort,
      'email_confirm': true,
    });
    userId = (jsonDecode(angelegt) as Map)['id'] as String?;
    expect(userId, isNotNull);
  });

  tearDownAll(() async {
    await client.auth.signOut().catchError((_) {});
    if (userId != null) {
      await _admin('DELETE', '/auth/v1/admin/users/$userId');
    }
    await client.dispose();
  });

  test('Einrichten hebt die Sitzung erst nach dem Code auf aal2', () async {
    await client.auth.signInWithPassword(email: _mail, password: _passwort);
    // Ohne Faktor verlangt niemand etwas: nextLevel bleibt aal1.
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().nextLevel,
        AuthenticatorAssuranceLevels.aal1);

    final angelegt = await client.auth.mfa
        .enroll(factorType: FactorType.totp, friendlyName: 'Test');
    final secret = angelegt.totp!.secret;

    // Vor der Bestätigung zählt der Faktor nicht — sonst käme jemand mit
    // einem halben Einrichtungsversuch durch die Pflicht.
    final vorher = await client.auth.mfa.listFactors();
    expect(vorher.totp.where((f) => f.status == FactorStatus.verified),
        isEmpty);

    await client.auth.mfa
        .challengeAndVerify(factorId: angelegt.id, code: _totp(secret));

    final nachher = await client.auth.mfa.listFactors();
    expect(nachher.totp.where((f) => f.status == FactorStatus.verified).length,
        1);
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel,
        AuthenticatorAssuranceLevels.aal2);

    // Der eigentliche Punkt: Nach einer frischen Passwort-Anmeldung steht
    // die Sitzung wieder auf aal1 und VERLANGT aal2. Genau daran hängt der
    // Router-Guard — ohne das wäre der zweite Faktor eine Zierde.
    await client.auth.signOut();
    await client.auth.signInWithPassword(email: _mail, password: _passwort);
    final stufen = client.auth.mfa.getAuthenticatorAssuranceLevel();
    expect(stufen.currentLevel, AuthenticatorAssuranceLevels.aal1);
    expect(stufen.nextLevel, AuthenticatorAssuranceLevels.aal2);

    // Falscher Code ändert nichts.
    final faktorId = nachher.totp.first.id;
    await expectLater(
      client.auth.mfa.challengeAndVerify(factorId: faktorId, code: '000000'),
      throwsA(isA<AuthException>()),
    );
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel,
        AuthenticatorAssuranceLevels.aal1);

    // Richtiger Code hebt sie.
    await client.auth.mfa
        .challengeAndVerify(factorId: faktorId, code: _totp(secret));
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel,
        AuthenticatorAssuranceLevels.aal2);
  });

  test('ein Admin kann den Faktor zurücksetzen (Telefon verloren)', () async {
    // Denselben Weg geht die Aktion clear_mfa in der Edge Function.
    final liste = await _admin('GET', '/auth/v1/admin/users/$userId/factors');
    final factors = jsonDecode(liste) as List<dynamic>;
    expect(factors, isNotEmpty, reason: 'Vorbedingung aus dem ersten Test');

    for (final f in factors) {
      await _admin('DELETE',
          '/auth/v1/admin/users/$userId/factors/${(f as Map)['id']}');
    }

    // Zweite Zusicherung: Danach kommt man wieder allein mit dem Passwort
    // hinein — sonst wäre ein verlorenes Telefon ein verlorenes Konto.
    await client.auth.signOut();
    await client.auth.signInWithPassword(email: _mail, password: _passwort);
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().nextLevel,
        AuthenticatorAssuranceLevels.aal1);
  });
}
