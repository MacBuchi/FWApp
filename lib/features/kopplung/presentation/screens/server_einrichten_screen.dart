/// server_einrichten_screen.dart – „Mit dem Server deiner Wehr verbinden"
/// (Issue #238, Teil des Installationskonzepts #234).
///
/// Die App aus dem Release trägt die Adresse EINES Servers in sich. Eine
/// Wehr mit eigener Installation braucht deshalb einen Weg, ihren Server
/// einzutragen, ohne Adresse und Schlüssel abzutippen — Marcus' Wort dafür:
/// Plug and Play. Zwei Wege, entschieden am 2026-09-23:
///
///   * **QR-Code scannen** — den zeigt jedes angemeldete Mitglied unter
///     Einstellungen → „Weiteres Gerät verbinden". Geht ohne Dritte und
///     ohne Tippen. Nur in der Android-App: Die Web-App findet ihren Server
///     selbst (siehe `waehleWebServer`).
///   * **Adresse eingeben** — die Domain der Wehr; die App holt sich den
///     Rest aus `/.well-known/fwapp.json`.
///
/// Von Hand eintragen bleibt als Rückfall über die Servereinstellungen.
/// Ohne Anmeldung erreichbar, wie die Servereinstellungen: Wer mit dem
/// falschen Server startet, steht sonst vor dem Anmeldezwang eines Servers,
/// auf dem er gar kein Konto hat.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/scanner/code_scannen_screen.dart';
import 'package:fwapp/features/kopplung/data/kopplung_quelle.dart';
import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:fwapp/features/kopplung/presentation/providers/kopplung_providers.dart';

class ServerEinrichtenScreen extends ConsumerStatefulWidget {
  /// Ob der QR-Weg angeboten wird. Vorgabe: nicht im Browser. Als Parameter,
  /// damit der Test beide Zweige sieht — `kIsWeb` ist im Test immer false
  /// (AGENTS.md, Issue #210).
  final bool mitQr;

  const ServerEinrichtenScreen({super.key, this.mitQr = !kIsWeb});

  @override
  ConsumerState<ServerEinrichtenScreen> createState() =>
      _ServerEinrichtenScreenState();
}

class _ServerEinrichtenScreenState
    extends ConsumerState<ServerEinrichtenScreen> {
  final _adresse = TextEditingController();
  bool _beschaeftigt = false;
  String? _fehler;

  @override
  void dispose() {
    _adresse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server einrichten'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mit dem Server deiner Wehr verbinden',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Nötig, wenn deine Feuerwehr einen eigenen Server betreibt. '
            'Frag im Zweifel deinen Kommandanten.',
          ),
          const SizedBox(height: 16),
          if (widget.mitQr) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('QR-Code scannen'),
                subtitle: const Text(
                  'Jedes Mitglied deiner Wehr kann ihn zeigen: '
                  'Einstellungen → „Weiteres Gerät verbinden".',
                ),
                enabled: !_beschaeftigt,
                onTap: _scannen,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Adresse eingeben', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _adresse,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_beschaeftigt,
            decoration: InputDecoration(
              hintText: 'z. B. feuerwehr-musterstadt.de',
              errorText: _fehler,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _perAdresse(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _beschaeftigt ? null : _perAdresse,
              child:
                  _beschaeftigt
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Verbinden'),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.push('/server-settings'),
            child: const Text('Adresse und Schlüssel von Hand eintragen'),
          ),
        ],
      ),
    );
  }

  Future<void> _scannen() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => const CodeScannenScreen(titel: 'Einrichtungs-Code scannen'),
      ),
    );
    if (text == null || !mounted) return;
    final ServerKopplung k;
    try {
      k = ServerKopplung.ausJson(text);
    } on KopplungFehler catch (e) {
      setState(() => _fehler = e.text);
      return;
    }
    await _uebernehmen(k, ServerQuelle.qr);
  }

  Future<void> _perAdresse() async {
    final adresse = kopplungsAdresse(_adresse.text);
    if (adresse == null) {
      setState(() => _fehler = 'Bitte eine Adresse eingeben.');
      return;
    }
    setState(() {
      _beschaeftigt = true;
      _fehler = null;
    });
    try {
      final k = await ref.read(kopplungsDiensteProvider).hole(adresse);
      if (!mounted) return;
      setState(() => _beschaeftigt = false);
      await _uebernehmen(k, ServerQuelle.domain);
    } on KopplungFehler catch (e) {
      if (mounted) {
        setState(() {
          _beschaeftigt = false;
          _fehler = e.text;
        });
      }
    }
  }

  /// Rückfrage, prüfen, speichern, neu starten — in dieser Reihenfolge.
  /// Geprüft wird VOR dem Speichern: Eine Adresse, hinter der nichts
  /// antwortet, sperrte den Nutzer nach dem Neustart hinter den
  /// Anmeldezwang eines toten Servers.
  Future<void> _uebernehmen(ServerKopplung k, ServerQuelle quelle) async {
    final ja = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text('Mit „${k.anzeige}" verbinden?'),
            content: Text(
              'Server: ${k.url}\n\n'
              'Danach startet die App neu und du meldest dich mit dem Zugang '
              'deiner Wehr an.\n\n'
              // ⚠️ Was hier erfasst und nie veröffentlicht wurde, kennt nur
              // dieses Gerät — nach dem Wechsel ginge es beim nächsten
              // Veröffentlichen an den NEUEN Server. Auf einem frischen Handy
              // (der Normalfall) gibt es so etwas nicht.
              'Hast du auf diesem Gerät für einen anderen Server etwas '
              'erfasst und noch nicht veröffentlicht, tu das vorher.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Verbinden'),
              ),
            ],
          ),
    );
    if (ja != true || !mounted) return;

    final dienste = ref.read(kopplungsDiensteProvider);
    setState(() {
      _beschaeftigt = true;
      _fehler = null;
    });
    try {
      await dienste.pruefe(k);
      await dienste.speichere(k, quelle);
    } on KopplungFehler catch (e) {
      if (mounted) {
        setState(() {
          _beschaeftigt = false;
          _fehler = e.text;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _beschaeftigt = false);
    if (dienste.neuStarten()) return;
    // Android: kein sauberer Neustart aus der App heraus.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialog) => AlertDialog(
            title: const Text('Fast geschafft'),
            content: Text(
              '„${k.anzeige}" ist eingetragen. Bitte die App jetzt ganz schließen '
              '(auch aus der Liste der offenen Apps) und neu öffnen.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Verstanden'),
              ),
            ],
          ),
    );
  }
}
