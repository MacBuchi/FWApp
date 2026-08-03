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
///
/// Seit Etappe 2 hat der Screen drei Zustände: anmelden, Adresse eingeben,
/// Code einlösen. Bewusst EIN Screen statt dreier Routen — der Ablauf gehört
/// zusammen, und ein Wechsel mitten im Zurücksetzen würde die halbe Sitzung
/// aus `verifyOTP` unbeaufsichtigt zurücklassen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/mfa_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/password_field.dart';
import 'package:fwapp/features/settings/presentation/widgets/sync_config_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FactorStatus, OtpType, UserAttributes;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// anmelden → Adresse (Passwort vergessen) → Code einlösen.
/// Daneben: einladung — der Weg für ein Konto, das es noch gar nicht gibt.
/// Quer dazu: zweiterFaktor, wenn das Konto TOTP eingerichtet hat.
enum _Modus { anmelden, adresse, code, einladung, zweiterFaktor }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _mail = TextEditingController();
  final _code = TextEditingController();
  final _neu1 = TextEditingController();
  final _neu2 = TextEditingController();
  final _totp = TextEditingController();

  /// Fokus für das jeweils ERSTE Feld der gerade gezeigten Ansicht.
  ///
  /// ⚠️ Daran hängt der Passwortmanager (Issue #120). Flutter-Web baut das
  /// DOM-Formular, an dem Bitwarden & Co. andocken, für das Feld mit Fokus —
  /// und baut es beim Moduswechsel NICHT neu. Gemessen: Nach dem Wechsel auf
  /// „Einladung einlösen" stand im DOM noch das Anmelde-Formular mit
  /// `username`/`current-password`, während die sichtbaren Felder als
  /// namenlose `autocomplete="off"` daneben lagen. Der Manager bot deshalb
  /// nichts an, und „generiertes Passwort einfügen" tat sichtbar nichts.
  ///
  /// `autofocus: true` an den Feldern reicht nicht: Beim Wechsel innerhalb
  /// desselben Bildschirms wird es nicht erneut ausgewertet.
  final _fokusErstes = FocusNode();
  var _modus = _Modus.anmelden;
  bool _busy = false;
  String? _error;
  /// Hinweise (kein Fehler) teilen sich den Platz mit [_error] — sie stehen
  /// nur in einer anderen Farbe da, weil sie dieselbe Frage beantworten:
  /// „Was ist gerade passiert?"
  String? _hinweis;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _mail.dispose();
    _code.dispose();
    _neu1.dispose();
    _neu2.dispose();
    _totp.dispose();
    _fokusErstes.dispose();
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
      // Zweiter Faktor eingerichtet? Dann steht die Sitzung erst auf aal1.
      // Das Flag hält den Router still, bis der Code stimmt — sonst wäre
      // der zweite Faktor eine Zierde.
      if (brauchtZweitenFaktor(client)) {
        ref.read(mfaOffenProvider.notifier).state = true;
        if (!mounted) return;
        setState(() {
          _modus = _Modus.zweiterFaktor;
          _hinweis = 'Bitte den Code aus deiner Authenticator-App eingeben.';
        });
        _fokusAufErstesFeld();
        return;
      }
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

  /// Fordert einen Code an. Antwortet IMMER gleich — Erfolg und Fehlschlag
  /// führen auf denselben Bildschirm mit demselben Satz. Sonst wäre der
  /// Screen ein Auskunftsdienst darüber, wer hier ein Konto hat.
  Future<void> _codeAnfordern() async {
    final client = ref.read(supabaseClientProvider);
    final mail = _mail.text.trim().toLowerCase();
    if (client == null || !mail.contains('@')) {
      setState(() => _error = 'Bitte eine vollständige E-Mail-Adresse angeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.auth.resetPasswordForEmail(mail);
    } catch (e, s) {
      // Absichtlich verschluckt: Der Grund darf den Nutzer nicht erreichen.
      // Die Adresse selbst gehört nicht ins Protokoll.
      appLog.w('Code-Anforderung fehlgeschlagen', error: e, stackTrace: s);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _modus = _Modus.code;
          _hinweis = 'Wenn es zu dieser Adresse ein Konto gibt, ist ein Code '
              'unterwegs. Er gilt eine Stunde.';
        });
        _fokusAufErstesFeld();
      }
    }
  }

  /// Löst den Code ein und setzt das neue Passwort in einem Zug.
  ///
  /// Die Reihenfolge ist heikel: `verifyOTP` erzeugt eine gültige Sitzung,
  /// BEVOR das neue Passwort existiert. Bliebe es dabei stehen, wäre jemand
  /// angemeldet, ohne sein Passwort zu kennen. Deshalb hängt `updateUser`
  /// unmittelbar daran, das Recovery-Flag hält den Router so lange still,
  /// und jeder Fehlschlag verwirft die halbe Sitzung wieder.
  Future<void> _codeEinloesen() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    // Passwortregeln VOR dem Einlösen prüfen: Ein Code ist einmalig, ein
    // Tippfehler im Passwort würde ihn sonst verbrennen.
    final fehler = validateNewPassword(_neu1.text, _neu2.text);
    if (fehler != null) {
      setState(() {
        _error = fehler;
        _hinweis = null;
      });
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() {
        _error = 'Bitte den Code aus der E-Mail eingeben.';
        _hinweis = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _hinweis = null;
    });
    ref.read(recoveryPendingProvider.notifier).state = true;
    try {
      await client.auth.verifyOTP(
        email: _mail.text.trim().toLowerCase(),
        token: _code.text.trim(),
        type: OtpType.recovery,
      );
      await client.auth.updateUser(UserAttributes(password: _neu1.text));
      // Wer sein Passwort gerade selbst gewählt hat, braucht danach keinen
      // Pflichtwechsel mehr — sonst stünde er direkt wieder vor einem.
      await client.rpc('clear_must_change_password');
      ref.invalidate(mustChangePasswordProvider);
      if (!mounted) return;
      // Erst jetzt darf der Router weiterschalten: Das Flag fällt, der
      // Listener stößt an, der Guard führt in die App.
      ref.read(recoveryPendingProvider.notifier).state = false;
      return;
    } catch (e, s) {
      // Halbe Sitzung wegwerfen — sie gehört zu einem Passwort, das der
      // Nutzer nicht gesetzt hat.
      await client.auth.signOut().catchError((_) {});
      appLog.w('Zurücksetzen fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Code stimmt nicht oder ist abgelaufen. '
          'Bitte einen neuen anfordern.');
    } finally {
      if (mounted) {
        ref.read(recoveryPendingProvider.notifier).state = false;
        setState(() => _busy = false);
      }
    }
  }

  /// Löst eine Einladung ein: Code prüfen, eigenes Passwort setzen.
  ///
  /// Dieselbe heikle Reihenfolge wie beim Zurücksetzen — `verifyOTP` erzeugt
  /// eine gültige Sitzung, BEVOR ein Passwort existiert. Bliebe es dabei
  /// stehen, wäre jemand angemeldet, ohne sein Passwort zu kennen, und käme
  /// beim nächsten Start nicht mehr hinein.
  ///
  /// Erst dieses Einlösen bestätigt die Adresse — und erst dadurch entsteht
  /// auf dem Server die Mitgliedschaft (Trigger `on_auth_user_confirmed`).
  /// Bis dahin ist die Einladung nur eine Einladung, das Konto hat kein Recht.
  ///
  /// `clear_must_change_password` wie beim Zurücksetzen braucht es hier
  /// nicht: Das Flag setzt ausschließlich ein Verwalter beim Vergeben eines
  /// Initialpassworts, ein eingeladenes Konto hatte nie eines.
  Future<void> _einladungAnnehmen() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    final mail = _mail.text.trim().toLowerCase();
    if (!mail.contains('@')) {
      setState(() {
        _error = 'Bitte die E-Mail-Adresse eingeben, an die die Einladung '
            'ging.';
        _hinweis = null;
      });
      return;
    }
    // Passwortregeln VOR dem Einlösen prüfen: Der Code ist einmalig, ein
    // Tippfehler im Passwort würde ihn sonst verbrennen.
    final fehler = validateNewPassword(_neu1.text, _neu2.text);
    if (fehler != null) {
      setState(() {
        _error = fehler;
        _hinweis = null;
      });
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() {
        _error = 'Bitte den Code aus der Einladungsmail eingeben.';
        _hinweis = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _hinweis = null;
    });
    ref.read(recoveryPendingProvider.notifier).state = true;
    try {
      await client.auth.verifyOTP(
        email: mail,
        token: _code.text.trim(),
        type: OtpType.invite,
      );
      await client.auth.updateUser(UserAttributes(password: _neu1.text));
      if (!mounted) return;
      ref.read(recoveryPendingProvider.notifier).state = false;
      return;
    } catch (e, s) {
      // Halbe Sitzung wegwerfen — sie gehört zu einem Passwort, das der
      // Nutzer nicht gesetzt hat.
      await client.auth.signOut().catchError((_) {});
      appLog.w('Einladung annehmen fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Code stimmt nicht oder ist abgelaufen. '
          'Bitte deinen Kommandanten um eine neue Einladung.');
    } finally {
      if (mounted) {
        ref.read(recoveryPendingProvider.notifier).state = false;
        setState(() => _busy = false);
      }
    }
  }

  /// Löst den zweiten Faktor ein und hebt die Sitzung auf aal2.
  Future<void> _zweitenFaktorPruefen() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    final faktoren = await ref.read(mfaFaktorenProvider.future);
    final faktor = faktoren.where((f) => f.status == FactorStatus.verified);
    if (faktor.isEmpty) {
      // Kann passieren, wenn ein Admin den Faktor gerade zurückgesetzt hat.
      ref.read(mfaOffenProvider.notifier).state = false;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _hinweis = null;
    });
    try {
      await client.auth.mfa.challengeAndVerify(
        factorId: faktor.first.id,
        code: _totp.text.trim(),
      );
      // Erst jetzt weiterschalten: Flag fällt, der Router wertet neu aus.
      ref.read(mfaOffenProvider.notifier).state = false;
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Der Code stimmt nicht oder ist abgelaufen. '
          'Die App zeigt alle 30 Sekunden einen neuen. (${e.message})');
    } catch (e, s) {
      appLog.w('Zweiter Faktor fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Server ist nicht erreichbar.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bricht die halbe Anmeldung ab und räumt die aal1-Sitzung weg.
  Future<void> _abbrechen() async {
    await ref.read(supabaseClientProvider)?.auth.signOut();
    ref.read(mfaOffenProvider.notifier).state = false;
    if (mounted) _wechsle(_Modus.anmelden);
  }

  Future<void> _absenden() => switch (_modus) {
        _Modus.anmelden => _signIn(),
        _Modus.adresse => _codeAnfordern(),
        _Modus.code => _codeEinloesen(),
        _Modus.einladung => _einladungAnnehmen(),
        _Modus.zweiterFaktor => _zweitenFaktorPruefen(),
      };

  void _wechsle(_Modus ziel) {
    setState(() {
      _modus = ziel;
      _error = null;
      _hinweis = switch (ziel) {
        _Modus.adresse =>
          'Das funktioniert nur für Konten mit hinterlegter E-Mail-Adresse '
              '(Admins und Gerätewarte). Mit einem Zugangszettel-Konto hilft '
              'der Gerätewart weiter.',
        _Modus.einladung =>
          'Trage die Adresse ein, an die die Einladung ging, dazu den Code '
              'aus der Mail — und wähle dein eigenes Passwort.',
        _ => null,
      };
    });
    _fokusAufErstesFeld();
  }

  /// Nach JEDEM Wechsel der Ansicht aufrufen — auch bei den beiden, die an
  /// [_wechsle] vorbeigehen (zweiter Faktor, Code angefordert). Erst nach dem
  /// Neubau anfordern: Vorher gibt es das Feld der neuen Ansicht noch nicht.
  void _fokusAufErstesFeld() {
    // ⚠️ Erst abgeben, dann neu anfordern. [_fokusErstes] hängt in JEDER
    // Ansicht am ersten Feld und behält den Fokus über den Wechsel hinweg —
    // ein `requestFocus` auf einen Knoten, der ihn schon hat, tut nichts,
    // und ohne Fokus-WECHSEL meldet Flutter dem Browser keinen neuen
    // Eingabekontext. Genau daran hing das DOM-Formular für den
    // Passwortmanager (#120): Es entstand erst beim Hineinklicken von Hand.
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fokusErstes.requestFocus();
    });
  }

  List<Widget> _felder() => switch (_modus) {
        _Modus.anmelden => [
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Nutzername',
                helperText: 'Vom Zugangszettel (oder vollständige E-Mail)',
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              focusNode: _fokusErstes,
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
          ],
        _Modus.adresse => [
            TextField(
              controller: _mail,
              decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              focusNode: _fokusErstes,
              autofocus: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _busy ? null : _codeAnfordern(),
            ),
          ],
        _Modus.zweiterFaktor => [
            TextField(
              controller: _totp,
              decoration: const InputDecoration(
                labelText: 'Code aus der Authenticator-App',
                helperText: 'Sechs Ziffern, wechselt alle 30 Sekunden',
              ),
              keyboardType: TextInputType.number,
              autocorrect: false,
              focusNode: _fokusErstes,
              autofocus: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _busy ? null : _zweitenFaktorPruefen(),
            ),
          ],
        _Modus.code => [
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code aus der E-Mail',
                helperText: 'Sechs Ziffern',
              ),
              keyboardType: TextInputType.number,
              autocorrect: false,
              focusNode: _fokusErstes,
              autofocus: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
            ),
            const SizedBox(height: 8),
            PasswordField(
              controller: _neu1,
              labelText: 'Neues Passwort',
              helperText: 'Mindestens 8 Zeichen',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            PasswordField(
              controller: _neu2,
              labelText: 'Passwort wiederholen',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _codeEinloesen(),
            ),
          ],
        // Wie _Modus.code, aber mit dem Adressfeld davor: Wer eine Einladung
        // annimmt, hat noch kein Konto und kommt nicht über „Passwort
        // vergessen" — die Adresse muss er hier selbst eintragen.
        _Modus.einladung => [
            TextField(
              controller: _mail,
              decoration: const InputDecoration(
                labelText: 'E-Mail-Adresse',
                helperText: 'Die Adresse, an die die Einladung ging',
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              focusNode: _fokusErstes,
              autofocus: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code aus der Einladung',
                helperText: 'Sechs Ziffern',
              ),
              keyboardType: TextInputType.number,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
            ),
            const SizedBox(height: 8),
            PasswordField(
              controller: _neu1,
              labelText: 'Passwort wählen',
              helperText: 'Mindestens 8 Zeichen',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            PasswordField(
              controller: _neu2,
              labelText: 'Passwort wiederholen',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _einladungAnnehmen(),
            ),
          ],
      };

  List<Widget> _nebenwege() => switch (_modus) {
        _Modus.anmelden => [
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.adresse),
              child: const Text('Passwort vergessen?'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.einladung),
              child: const Text('Ich habe eine Einladung'),
            ),
            const Text(
              'Keine Registrierung nötig — den Zugang vergibt der Kommandant: '
              'per Einladung an deine E-Mail-Adresse oder mit einem '
              'Zugangszettel aus dem Gerätehaus.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextButton(
              onPressed: () => context.push('/server-settings'),
              child: const Text('Servereinstellungen'),
            ),
          ],
        _Modus.adresse => [
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.anmelden),
              child: const Text('Zurück zur Anmeldung'),
            ),
          ],
        _Modus.zweiterFaktor => [
            TextButton(
              onPressed: _busy ? null : _abbrechen,
              child: const Text('Abbrechen'),
            ),
            const Text(
              'Kein Zugriff auf die Authenticator-App? Ein Admin kann den '
              'zweiten Faktor in der Nutzerverwaltung zurücksetzen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        _Modus.code => [
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.adresse),
              child: const Text('Neuen Code anfordern'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.anmelden),
              child: const Text('Zurück zur Anmeldung'),
            ),
          ],
        _Modus.einladung => [
            TextButton(
              onPressed: _busy ? null : () => _wechsle(_Modus.anmelden),
              child: const Text('Zurück zur Anmeldung'),
            ),
            const Text(
              'Keine Einladung erhalten? Der Kommandant kann sie erneut '
              'schicken — der Code gilt mindestens eine Stunde.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
      };

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
                // ⚠️ Der Schlüssel ist der eigentliche Fix für #120: Flutter
                // baut den Autofill-Kontext (und damit das DOM-Formular, an
                // dem ein Passwortmanager andockt) EINMAL je AutofillGroup
                // auf. Ohne eigenen Schlüssel bleibt beim Moduswechsel das
                // Anmelde-Formular im DOM stehen, während die sichtbaren
                // Felder als namenlose `autocomplete="off"` daneben liegen —
                // im Browser gemessen. Ein Wechsel des Schlüssels wirft die
                // Gruppe weg und lässt eine neue entstehen.
                child: AutofillGroup(
                  key: ValueKey(_modus),
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
                      ..._felder(),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      if (_hinweis != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _hinweis!,
                            style:
                                TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      SizedBox(height: eng ? 8 : 16),
                      FilledButton(
                        onPressed: _busy ? null : _absenden,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(switch (_modus) {
                                _Modus.anmelden => 'Anmelden',
                                _Modus.adresse => 'Code anfordern',
                                _Modus.code => 'Passwort setzen',
                                _Modus.einladung => 'Einladung annehmen',
                                _Modus.zweiterFaktor => 'Bestätigen',
                              }),
                      ),
                      ..._nebenwege(),
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
