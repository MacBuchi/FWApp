/// login_screen.dart – Die Anmeldung (Issue #57 Phase 4, Etappe 2).
///
/// Bis v1.6.3 steckte der Login als Dialog in den Einstellungen und war
/// überspringbar: Wer ihn nie öffnete, sah die ganze App — nur eben ohne
/// Daten, weil ohne Sitzung nichts vom Server kommt. Seit dem Anmeldezwang
/// ist das hier die erste Seite einer verbundenen Installation; die Sperre
/// selbst sitzt in `guardRedirect` (app_router.dart), nicht in diesem Screen.
///
/// Keine Repository-Schicht: Anmelden ist ein Ablauf, keine Entität — wie
/// beim Import. Den Lokalmodus (kein Server konfiguriert) löst FWApp über
/// `supabaseReadyProvider`, nicht über eine Attrappe des Auth-Zugriffs.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/password_field.dart';
import 'package:fwapp/features/settings/presentation/widgets/sync_config_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      setState(() => _error = 'Kein Server konfiguriert — bitte unter '
          '„Servereinstellungen“ Adresse und Schlüssel eintragen.');
      return;
    }
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Bitte Nutzername und Passwort eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.auth.signInWithPassword(
        email: loginInputToEmail(_user.text),
        password: _password.text,
      );
      // Signal an den Passwortmanager, die Zugangsdaten zu sichern.
      TextInput.finishAutofillContext();
      // Bewusst KEIN context.go(): Das Auth-Ereignis stößt den Router an,
      // guardRedirect bringt den Nutzer auf '/' oder '/change-password'. Ein
      // zweiter Weg wäre ein Rennen gegen den Redirect — und dieser Screen
      // ist in dem Moment bereits abgebaut.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = authErrorText(e.message, code: e.code));
    } catch (e, s) {
      // Niemals Nutzername oder Passwort mitloggen: Der Ring-Puffer landet
      // auf Wunsch in einem öffentlichen Issue.
      appLog.w('Anmeldung fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Server ist nicht erreichbar. '
          'Internetverbindung prüfen oder unter „Servereinstellungen“ die '
          'Adresse korrigieren.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Querformat und offene Tastatur lassen wenig Höhe übrig: Dann schrumpft
    // der Kopf, damit der Notausgang „Servereinstellungen" nicht unter die
    // Kante rutscht — er wird ja gerade dann gebraucht, wenn der Server
    // nicht antwortet und niemand ans Scrollen denkt.
    final eng = MediaQuery.sizeOf(context).height < 520;
    return Scaffold(
      body: SafeArea(
        child: Center(
          // Scrollbar und schmal gehalten: Das Testgerät liegt quer, mit
          // offener Tastatur bleibt wenig Höhe übrig (Feldtest Pixel XL).
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: eng ? 12 : 24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (eng)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_fire_department,
                                size: 28, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Feuerwehr-Lernapp',
                                style: theme.textTheme.titleMedium),
                          ],
                        )
                      else ...[
                        Icon(Icons.local_fire_department,
                            size: 72, color: theme.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text('Feuerwehr-Lernapp',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall),
                      ],
                      SizedBox(height: eng ? 4 : 16),
                      // Zeigt VOR dem Fehlversuch, ob der Server überhaupt
                      // antwortet — sonst sieht ein Netzproblem wie ein
                      // falsches Passwort aus.
                      const ServerHealthTile(),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(
                          labelText: 'Nutzername',
                          helperText:
                              'Vom Zugangszettel (oder vollständige E-Mail)',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 8),
                      PasswordField(
                        controller: _password,
                        labelText: 'Passwort',
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _signIn(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      SizedBox(height: eng ? 8 : 16),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Anmelden'),
                      ),
                      SizedBox(height: eng ? 8 : 16),
                      const Text(
                        'Keine Registrierung nötig — die Zugangsdaten vergibt '
                        'der Gerätewart (Zugangszettel im Gerätehaus).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () => context.push('/server-settings'),
                        child: const Text('Servereinstellungen'),
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
