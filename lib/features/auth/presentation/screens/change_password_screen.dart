/// change_password_screen.dart – Pflichtwechsel des Initialpassworts.
///
/// War bis v1.6.3 ein Dialog (`showForcedPasswordChange`) direkt nach dem
/// Login. Mit dem Anmeldezwang geht das nicht mehr: Das Auth-Ereignis stößt
/// den Redirect an, der den Login-Screen im selben Moment abräumt — der
/// Dialog erschiene auf einem abgebauten Kontext. Als eigene Route erledigt
/// derselbe Guard den Zwang, der auch die Anmeldung erzwingt.
///
/// Nebengewinn: Auch der Fall „Admin setzt das Flag, während jemand
/// angemeldet ist“ ist damit abgedeckt — vorher fing den nur eine Kachel in
/// den Einstellungen, die man übersehen konnte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/password_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, UserAttributes;

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fehler = validateNewPassword(_pw1.text, _pw2.text);
    if (fehler != null) {
      setState(() => _error = fehler);
      return;
    }
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.auth.updateUser(UserAttributes(password: _pw1.text));
      await client.rpc('clear_must_change_password');
      // Der Guard hört auf diesen Provider und gibt danach den Weg frei.
      ref.invalidate(mustChangePasswordProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Passwort geändert – Zugangszettel wegwerfen.')));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = authErrorText(e.message, code: e.code));
    } catch (e, s) {
      // Kein Passwort ins Protokoll — der Ring-Puffer geht in Issues.
      appLog.w('Passwortwechsel fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Server ist nicht erreichbar. '
          'Bitte Internetverbindung prüfen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neues Passwort festlegen'),
        // Kein Zurück-Pfeil: Der einzige Ausweg ist ein neues Passwort oder
        // Abmelden. Der Guard schickt ohnehin hierher zurück.
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Du bist mit einem Initialpasswort angemeldet. Bitte '
                        'lege jetzt dein eigenes Passwort fest (mindestens 8 '
                        'Zeichen).',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _pw1,
                        labelText: 'Neues Passwort',
                        autofocus: true,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
                      PasswordField(
                        controller: _pw2,
                        labelText: 'Passwort wiederholen',
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _save(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style:
                                  TextStyle(color: theme.colorScheme.error)),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Passwort setzen'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await ref
                                    .read(supabaseClientProvider)
                                    ?.auth
                                    .signOut();
                              },
                        child: const Text('Abmelden'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
