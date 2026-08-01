/// zwei_faktor_screen.dart – Zweiten Faktor einrichten (Issue #57 Phase 4,
/// Etappe 3).
///
/// Bewusst ohne QR-Code: Die App läuft in aller Regel auf demselben Telefon
/// wie die Authenticator-App, und ein Telefon kann seine eigene Anzeige
/// nicht scannen. Stattdessen führt ein Knopf direkt in die Authenticator-App
/// (`otpauth://`-Adresse), und wer sie auf einem anderen Gerät hat, tippt den
/// Schlüssel ab — dafür steht er in Viererblöcken da und lässt sich kopieren.
/// Das spart zugleich eine Abhängigkeit, die nur ein Bild zeichnet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/mfa_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FactorStatus, FactorType;
import 'package:url_launcher/url_launcher.dart';

class ZweiFaktorScreen extends ConsumerStatefulWidget {
  const ZweiFaktorScreen({super.key});

  @override
  ConsumerState<ZweiFaktorScreen> createState() => _ZweiFaktorScreenState();
}

class _ZweiFaktorScreenState extends ConsumerState<ZweiFaktorScreen> {
  final _code = TextEditingController();
  String? _faktorId;
  String? _secret;
  String? _uri;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Legt einen neuen, noch unbestätigten Faktor an und zeigt den Schlüssel.
  Future<void> _starten() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final antwort = await client.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: 'FWApp',
      );
      final totp = antwort.totp;
      if (!mounted) return;
      if (totp == null) {
        // Kann nur passieren, wenn der Server TOTP nicht anbietet — dann
        // hilft kein Wiederholen, sondern nur ein Hinweis.
        setState(() => _error = 'Dieser Server unterstützt keine '
            'Zwei-Faktor-Anmeldung.');
        return;
      }
      setState(() {
        _faktorId = antwort.id;
        _secret = totp.secret;
        _uri = totp.uri;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e, s) {
      // Der Schlüssel selbst darf NIE ins Protokoll — er ist das Geheimnis.
      appLog.w('Einrichtung des zweiten Faktors fehlgeschlagen',
          error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Server ist nicht erreichbar.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bestätigt den Faktor mit dem ersten Code — erst danach zählt er.
  Future<void> _bestaetigen() async {
    final client = ref.read(supabaseClientProvider);
    final id = _faktorId;
    if (client == null || id == null) return;
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'Bitte den sechsstelligen Code eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.auth.mfa
          .challengeAndVerify(factorId: id, code: _code.text.trim());
      // Der Guard hört auf die Faktorenliste und gibt den Weg danach frei.
      ref.invalidate(mfaFaktorenProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zweiter Faktor aktiv. Beim nächsten Anmelden wird '
              'der Code abgefragt.')));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Der Code stimmt nicht. Zeigt die '
          'Authenticator-App gerade einen anderen? (${e.message})');
    } catch (e, s) {
      appLog.w('Bestätigung des zweiten Faktors fehlgeschlagen',
          error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _error = 'Der Server ist nicht erreichbar.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _entfernen(String id) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() => _busy = true);
    try {
      await client.auth.mfa.unenroll(id);
      ref.invalidate(mfaFaktorenProvider);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faktoren = ref.watch(mfaFaktorenProvider).value ?? const [];
    final aktiv = faktoren.where((f) => f.status == FactorStatus.verified);
    final istAdmin = ref.watch(currentUserRoleProvider).value == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Zwei-Faktor-Anmeldung')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (aktiv.isNotEmpty) ...[
                      const ListTile(
                        leading: Icon(Icons.verified_user, color: Colors.green),
                        title: Text('Zweiter Faktor ist aktiv'),
                        subtitle: Text(
                            'Beim Anmelden fragt die App nach dem Code aus '
                            'deiner Authenticator-App.'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _entfernen(aktiv.first.id),
                        child: const Text('Zweiten Faktor entfernen'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Telefon verloren? Ein anderer Admin kann den Faktor '
                        'in der Nutzerverwaltung zurücksetzen.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ] else if (_secret == null) ...[
                      Text(
                        'Zusätzlich zum Passwort fragt die App dann '
                        'einen Zahlencode ab, den nur dein Telefon '
                        'erzeugt.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (istAdmin) ...[
                        const SizedBox(height: 8),
                        // Empfehlung statt Pflicht (Entscheidung 2026-08-01):
                        // Der Satz begründet, statt zu drohen.
                        Text(
                          'Für Admin-Konten empfohlen — sie können Konten '
                          'anlegen und den Datenbestand der ganzen Wehr '
                          'überschreiben.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Du brauchst eine Authenticator-App — zum Beispiel '
                        'Aegis, Google Authenticator oder die Passwort-App, '
                        'die du ohnehin nutzt.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _starten,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Einrichtung starten'),
                      ),
                    ] else ...[
                      Text('Schritt 1: Schlüssel übernehmen',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('In Authenticator-App öffnen'),
                        onPressed: _busy
                            ? null
                            : () async {
                                final ziel = Uri.parse(_uri!);
                                if (!await launchUrl(ziel)) {
                                  if (!context.mounted) return;
                                  setState(() => _error =
                                      'Keine Authenticator-App gefunden — '
                                      'bitte den Schlüssel abtippen.');
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      const Text('… oder diesen Schlüssel von Hand eintragen:',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      SelectableText(
                        schluesselLesbar(_secret!),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            letterSpacing: 1.2),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Schlüssel kopieren'),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: _secret!));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kopiert.')));
                        },
                      ),
                      const Divider(height: 32),
                      Text('Schritt 2: Code bestätigen',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Code aus der Authenticator-App',
                          helperText: 'Sechs Ziffern',
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onSubmitted: (_) => _busy ? null : _bestaetigen(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _bestaetigen,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Aktivieren'),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
