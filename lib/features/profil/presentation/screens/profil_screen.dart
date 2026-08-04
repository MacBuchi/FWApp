/// profil_screen.dart – „Mein Profil": Anzeigename und Avatar selbst wählen
/// (Nutzerkonzept Stufe ③, Issue #100).
///
/// Zwei Wege zum Kopf, wie im Entwurf „FWApp Avatare": 36 fertige Köpfe der
/// Mannschaft zum Antippen und darunter der Baukasten für alles Einzelne.
/// Die Vorlagen sind der schnelle Weg, der Baukasten der genaue — wer nur
/// eines von beidem bekommt, sitzt entweder lange davor oder findet sich
/// nicht wieder.
///
/// ⚠️ Eine Vorlage anzutippen ändert NUR das Aussehen, nie den Anzeigenamen:
/// „Bratwurst-Brigitte" ist der Name des Avatars, nicht der der Person.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/home/presentation/providers/dashboard_providers.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/domain/leistungsabzeichen.dart';
import 'package:fwapp/features/profil/presentation/providers/profil_providers.dart';
import 'package:fwapp/features/profil/presentation/widgets/abzeichen_zeile.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  final _name = TextEditingController();
  final _wuerfel = Random();

  AvatarKonfiguration _avatar = const AvatarKonfiguration();
  bool _uebernommen = false;
  bool _laeuft = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Einmalig aus dem geladenen Profil füllen — ein späteres Auffrischen
  /// würde sonst mitten im Tippen den Text austauschen (wie im Kopfbereich).
  void _uebernimm(MeinProfil? profil) {
    if (_uebernommen || profil == null) return;
    _uebernommen = true;
    _name.text = profil.anzeigename ?? '';
    _avatar = profil.avatar;
  }

  void _setze(AvatarKonfiguration neu) => setState(() => _avatar = neu);

  Future<void> _speichern() async {
    final service = ref.read(profilServiceProvider);
    if (service == null) return;
    setState(() => _laeuft = true);
    try {
      await service.speichere(anzeigename: _name.text, avatar: _avatar);
      if (!mounted) return;
      _melde('Profil gespeichert.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      _melde(profilFehlerText(e));
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  void _melde(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final profilAsync = ref.watch(meinProfilProvider);
    _uebernimm(profilAsync.value);
    final profil = profilAsync.value;
    final email = ref.watch(sessionStreamProvider).value?.user.email;
    // Lernzahlen dieses Geräts (Issue #135). Bevor sie geladen sind, steht
    // hier nichts — kein Platzhalter, der später etwas anderes behauptet.
    final level = ref.watch(lernLevelProvider);
    final theme = Theme.of(context);
    final kannSpeichern = profil?.serverKenntProfil ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Mein Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                FwAvatar(
                  konfiguration: _avatar,
                  groesse: 132,
                  abzeichen: level == null ? null : abzeichenFuerLevel(level),
                ),
                const SizedBox(height: 8),
                Text(
                  _name.text.trim().isEmpty
                      ? (profil?.username ?? email ?? 'Dein Konto')
                      : _name.text.trim(),
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (email != null)
                  Text(
                    'Angemeldet als $email',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                if (level != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AbzeichenZeile(level: level),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Anzeigename',
              helperText: 'So stehen dein Name und dein Kopf in der '
                  'Nutzerverwaltung. Leer = dein Nutzername.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!kannSpeichern && profilAsync.hasValue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dieser Server kennt Profile noch nicht — Anzeigename und '
                'Avatar lassen sich erst nach seiner Aktualisierung '
                'speichern.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _setze(wuerfleAvatar((n) => _wuerfel.nextInt(n))),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Zufällig würfeln'),
            ),
          ),
          const _Abschnitt(
            'Die Mannschaft',
            'Antippen übernimmt den Kopf. Der Name daneben gehört zum '
                'Avatar, nicht zu dir.',
          ),
          _Vorlagen(gewaehlt: _avatar, onWahl: _setze),
          const _Abschnitt(
            'Baukasten',
            'Alles Einzelne — vom Helm bis zum Schnauzer.',
          ),
          _Wahl(
            'Kopfbedeckung',
            werte: kAvatarGears,
            labels: kAvatarGearLabels,
            aktiv: _avatar.gear,
            onWahl: (v) => _setze(_avatar.copyWith(gear: v)),
          ),
          _Farben(
            'Helmfarbe',
            farben: kAvatarGearColors,
            aktiv: _avatar.gearColor,
            onWahl: (c) => _setze(_avatar.copyWith(gearColor: c)),
          ),
          _Wahl(
            'Augen',
            werte: kAvatarEyes,
            labels: kAvatarEyesLabels,
            aktiv: _avatar.eyes,
            onWahl: (v) => _setze(_avatar.copyWith(eyes: v)),
          ),
          _Wahl(
            'Mund',
            werte: kAvatarMouths,
            labels: kAvatarMouthLabels,
            aktiv: _avatar.mouth,
            onWahl: (v) => _setze(_avatar.copyWith(mouth: v)),
          ),
          _Wahl(
            'Bart',
            werte: kAvatarHair,
            labels: kAvatarHairLabels,
            aktiv: _avatar.hair,
            onWahl: (v) => _setze(_avatar.copyWith(hair: v)),
            // Ehrlicher als die Auswahl auszublenden: Sie bleibt gespeichert
            // und taucht wieder auf, sobald die Maske abgesetzt wird.
            hinweis: _avatar.gear == 'scba'
                ? 'Unter der Atemschutzmaske sieht man davon nichts.'
                : _avatar.gear == 'dog'
                    ? 'Der Dalmatiner trägt keinen Bart.'
                    : null,
          ),
          _Farben(
            'Hautton',
            farben: kAvatarSkins,
            aktiv: _avatar.skin,
            onWahl: (c) => _setze(_avatar.copyWith(skin: c)),
          ),
          _Farben(
            'Haarfarbe',
            farben: kAvatarHairColors,
            aktiv: _avatar.hairColor,
            onWahl: (c) => _setze(_avatar.copyWith(hairColor: c)),
          ),
          _Farben(
            'Hintergrund',
            farben: kAvatarBgs,
            aktiv: _avatar.bg,
            onWahl: (c) => _setze(_avatar.copyWith(bg: c)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _laeuft || !kannSpeichern ? null : _speichern,
            icon: _laeuft
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt(this.titel, this.text);

  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: theme.textTheme.titleMedium),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Die 36 Vorlagen als Raster.
class _Vorlagen extends StatelessWidget {
  const _Vorlagen({required this.gewaehlt, required this.onWahl});

  final AvatarKonfiguration gewaehlt;
  final ValueChanged<AvatarKonfiguration> onWahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in kAvatarVorlagen)
          SizedBox(
            width: 96,
            child: InkWell(
              onTap: () => onWahl(v.kopf),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 2,
                          color: v.kopf == gewaehlt
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: FwAvatar(
                        konfiguration: v.kopf,
                        groesse: 64,
                        semantikLabel: '${v.name}, ${v.rolle}',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      v.rolle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Eine Reihe benannter Auswahlmöglichkeiten (Kopfbedeckung, Augen, …).
class _Wahl extends StatelessWidget {
  const _Wahl(
    this.titel, {
    required this.werte,
    required this.labels,
    required this.aktiv,
    required this.onWahl,
    this.hinweis,
  });

  final String titel;
  final List<String> werte;
  final Map<String, String> labels;
  final String aktiv;
  final ValueChanged<String> onWahl;
  final String? hinweis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: theme.textTheme.labelLarge),
          if (hinweis != null)
            Text(hinweis!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in werte)
                ChoiceChip(
                  label: Text(labels[w] ?? w),
                  selected: w == aktiv,
                  onSelected: (_) => onWahl(w),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Eine Reihe Farbfelder.
class _Farben extends StatelessWidget {
  const _Farben(
    this.titel, {
    required this.farben,
    required this.aktiv,
    required this.onWahl,
  });

  final String titel;
  final List<Color> farben;
  final Color aktiv;
  final ValueChanged<Color> onWahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in farben)
                Semantics(
                  // Farbe allein trägt die Auswahl nicht: Der Haken macht sie
                  // auch für Screenreader und bei Farbfehlsichtigkeit sichtbar.
                  selected: f == aktiv,
                  button: true,
                  child: InkWell(
                    onTap: () => onWahl(f),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: f,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: f == aktiv ? 3 : 1,
                          color: f == aktiv
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: f == aktiv
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: ThemeData.estimateBrightnessForColor(f) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
