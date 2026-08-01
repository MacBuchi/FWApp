/// passwort_reset_e2e_test.dart – „Passwort vergessen" gegen den echten
/// Stack (Issue #57 Phase 4, Etappe 2).
///
/// Warum das kein Widget-Test sein kann: Die eine Aussage, auf der der ganze
/// Weg beruht — **die Mail enthält einen Code und keinen Link** — entsteht
/// erst aus dem Zusammenspiel von GoTrue, unserer Vorlage und dem
/// Mail-Versand. Ein Fake würde genau die Stelle nachbauen, die zu prüfen
/// ist. Stimmt sie nicht, scheitert draußen jeder, der die Mail auf einem
/// anderen Gerät öffnet als dem, das sie angefordert hat.
///
/// Voraussetzung: `supabase start` + `bash tool/setup_local_supabase.sh`.
/// Ohne laufenden Stack überspringt sich die Datei selbst.
library;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'http://127.0.0.1:54321';
const _mailpit = 'http://127.0.0.1:54324';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

/// Eine Adresse, die es nur in diesem Test gibt.
const _mail = 'reset.probe@example.org';
const _altesPasswort = 'test1234';
const _neuesPasswort = 'ganz-neu-9876';

Future<bool> _erreichbar(String url) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

typedef HttpResult = ({int status, String text});

/// Speicher für die PKCE-Prüfsumme.
///
/// `resetPasswordForEmail` erzeugt sie immer — die App bekommt den Speicher
/// über `Supabase.initialize`, ein nackter SupabaseClient hat keinen und
/// bricht mit einer Zusicherung ab. Damit der Test denselben Weg geht wie
/// die App, reicht hier eine Map. (Die Prüfsumme selbst braucht am Ende
/// niemand: Wir lösen per Code ein, nicht per Link — genau deshalb
/// funktioniert der Weg auch auf einem anderen Gerät.)
class _SpeicherImArbeitsspeicher implements GotrueAsyncStorage {
  final _werte = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _werte[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _werte[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _werte.remove(key);
}

Future<HttpResult> _json(String method, String url,
    {Map<String, dynamic>? body, String? key}) async {
  final client = HttpClient();
  final request = await client.openUrl(method, Uri.parse(url));
  request.headers.set('apikey', key ?? _serviceRoleKey);
  request.headers.set('Authorization', 'Bearer ${key ?? _serviceRoleKey}');
  request.headers.contentType = ContentType.json;
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  client.close();
  return (status: response.statusCode, text: text);
}

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health') ||
      !await _erreichbar(_mailpit)) {
    test('passwort-reset e2e', () {},
        skip: 'Lokaler Supabase-Stack oder Mailpit läuft nicht '
            '(supabase start).');
    return;
  }

  late SupabaseClient client;
  String? userId;

  setUpAll(() async {
    client = SupabaseClient(_url, _anonKey,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _SpeicherImArbeitsspeicher(),
        ));

    // Testkonto mit ECHTER Adresse anlegen — genau der Fall, den Etappe 2
    // ermöglicht. Ein @fw.local-Konto könnte die Mail nie empfangen.
    final angelegt = await _json('POST', '$_url/auth/v1/admin/users', body: {
      'email': _mail,
      'password': _altesPasswort,
      'email_confirm': true,
    });
    userId = (jsonDecode(angelegt.text) as Map)['id'] as String?;
    expect(userId, isNotNull, reason: 'Testkonto ließ sich nicht anlegen');

    // Postfach leeren, damit die gleich gesuchte Mail eindeutig ist.
    await _json('DELETE', '$_mailpit/api/v1/messages');
  });

  tearDownAll(() async {
    await client.auth.signOut().catchError((_) {});
    if (userId != null) {
      await _json('DELETE', '$_url/auth/v1/admin/users/$userId');
    }
    await _json('DELETE', '$_mailpit/api/v1/messages');
    await client.dispose();
  });

  /// Holt den Text der zuletzt zugestellten Mail.
  Future<String> letzteMail() async {
    final liste = await _json('GET', '$_mailpit/api/v1/messages');
    final nachrichten =
        (jsonDecode(liste.text) as Map)['messages'] as List<dynamic>;
    expect(nachrichten, isNotEmpty, reason: 'keine Mail in Mailpit');
    final id = (nachrichten.first as Map)['ID'] as String;
    final einzeln = await _json('GET', '$_mailpit/api/v1/message/$id');
    final m = jsonDecode(einzeln.text) as Map;
    return '${m['Text'] ?? ''}\n${m['HTML'] ?? ''}';
  }

  // Ein Durchlauf, mehrere Zusicherungen: GoTrue bremst wiederholte
  // Mail-Anforderungen an dasselbe Konto (429 over_email_send_rate_limit),
  // und der Ablauf IST eine zusammenhängende Nutzerreise.
  test('Mail trägt einen Code, der Code setzt das Passwort', () async {
    await client.auth.resetPasswordForEmail(_mail);
    // Zustellung ist nicht sofort; kurz nachfassen statt fest zu warten.
    var text = '';
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        text = await letzteMail();
        break;
      } catch (_) {/* noch nicht da */}
    }

    final treffer = RegExp(r'\b(\d{6})\b').firstMatch(text);
    expect(treffer, isNotNull,
        reason: 'ohne sechsstelligen Code ist der ganze Weg nutzlos');
    // Der eigentliche Regressionsschutz: Ein Link würde auf einem fremden
    // Gerät still scheitern, weil dort die PKCE-Prüfsumme fehlt.
    expect(text.contains('auth/v1/verify'), isFalse,
        reason: 'die Vorlage darf keinen Bestätigungslink enthalten');
    expect(text, contains('Passwort'));

    // Genau die Reihenfolge aus dem Screen: erst einlösen, dann sofort das
    // Passwort setzen — dazwischen wäre jemand angemeldet, ohne sein
    // Passwort zu kennen.
    await client.auth.verifyOTP(
        email: _mail, token: treffer!.group(1)!, type: OtpType.recovery);
    await client.auth.updateUser(UserAttributes(password: _neuesPasswort));
    await client.auth.signOut();

    // Gegenprobe in beide Richtungen: neues Passwort trägt …
    final neu = await client.auth
        .signInWithPassword(email: _mail, password: _neuesPasswort);
    expect(neu.session, isNotNull);
    await client.auth.signOut();

    // … und das alte ist wirklich weg, nicht bloß zusätzlich gültig.
    await expectLater(
      client.auth.signInWithPassword(email: _mail, password: _altesPasswort),
      throwsA(isA<AuthException>()),
    );
  });

  test('ein falscher Code ändert nichts', () async {
    await expectLater(
      client.auth
          .verifyOTP(email: _mail, token: '000000', type: OtpType.recovery),
      throwsA(isA<AuthException>()),
    );
    // Zweite Zusicherung: Der Zustand ist unverändert — das zuletzt
    // gesetzte Passwort gilt weiterhin.
    final immerNoch = await client.auth
        .signInWithPassword(email: _mail, password: _neuesPasswort);
    expect(immerNoch.session, isNotNull);
    await client.auth.signOut();
  });
}
