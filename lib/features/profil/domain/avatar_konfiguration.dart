/// avatar_konfiguration.dart – Der gezeichnete Feuerwehr-Kopf als acht Werte
/// (Issue #100, docs/NUTZERKONZEPT.md §2).
///
/// Warum gezeichnet und nicht fotografiert: Acht Werte passen in eine
/// Textspalte in `profiles` — kein Bucket, kein Upload, kein Bildabgleich,
/// kein Gesicht einer realen Person in der Datenbank. Und weil gezeichnet
/// statt geladen wird, steht der Kopf auch offline im Gerätehaus da.
///
/// Die technischen Schlüssel (`scba`, `happy`, `walrus` …) bleiben englisch
/// und stabil, die Beschriftung ist deutsch — dieselbe Trennung wie bei den
/// Rollen (core/sync/rollen.dart). Sie stammen aus dem Entwurf
/// „FWApp Avatare", damit Entwurf und App dieselbe Sprache sprechen.
library;

import 'dart:ui' show Color;

/// Kopfbedeckung. `dog` ist der Dalmatiner — er trägt ebenfalls einen Helm.
const kAvatarGears = ['helmet', 'visor', 'scba', 'cap', 'dog'];
const kAvatarEyes = ['happy', 'wide', 'squint', 'wink', 'dots', 'shades'];
const kAvatarMouths = ['grin', 'smirk', 'laugh', 'whistle', 'tongue'];
const kAvatarHair = ['none', 'mustache', 'walrus', 'beard', 'stubble'];

const kAvatarGearLabels = {
  'helmet': 'Helm',
  'visor': 'Helm + Visier',
  'scba': 'Atemschutzmaske',
  'cap': 'Käppi',
  'dog': 'Dalmatiner',
};
const kAvatarEyesLabels = {
  'happy': 'Lachfalten',
  'wide': 'Große Augen',
  'squint': 'Zusammengekniffen',
  'wink': 'Augenzwinkern',
  'dots': 'Punkte',
  'shades': 'Sonnenbrille',
};
const kAvatarMouthLabels = {
  'grin': 'Grinsen',
  'smirk': 'Schmunzeln',
  'laugh': 'Lachen',
  'whistle': 'Pfeifen',
  'tongue': 'Zunge raus',
};
const kAvatarHairLabels = {
  'none': 'Glatt rasiert',
  'mustache': 'Schnauzer',
  'walrus': 'Walross',
  'beard': 'Vollbart',
  'stubble': 'Stoppeln',
};

/// Die Farbfelder des Baukastens. Bewusst kurze Reihen: Ein freier
/// Farbwähler klingt großzügig, liefert aber neongrüne Helme — die Auswahl
/// IST hier die Gestaltung.
const kAvatarBgs = [
  Color(0xFFF4DCC7),
  Color(0xFFF6C9C2),
  Color(0xFFD6E3D8),
  Color(0xFFCBDCEA),
  Color(0xFFF0E5D2),
  Color(0xFFE2DAEA),
];
const kAvatarSkins = [
  Color(0xFFF6D3B2),
  Color(0xFFEFC199),
  Color(0xFFD79B69),
  Color(0xFFB87A4E),
  Color(0xFF8D5524),
];
const kAvatarHairColors = [
  Color(0xFF3E2B22),
  Color(0xFF161311),
  Color(0xFF8A5A32),
  Color(0xFFC9BCAE),
];
const kAvatarGearColors = [
  Color(0xFFC62828),
  Color(0xFF1F262B),
  Color(0xFFF2F2F0),
  Color(0xFFE8B33C),
];

/// Ein Avatar: acht Werte, sonst nichts.
///
/// Kein Abzeichen („AGT", „MA") — der Entwurf hat eines, die App bekommt
/// keines: Ein dauerhaft am Kopf klebendes „AGT" liest sich wie eine
/// hinterlegte Qualifikation, und die steht hier nirgends. Die Rollennamen
/// der Vorlagen sind Katalog-Beschriftungen, keine Nachweise.
class AvatarKonfiguration {
  final Color bg;
  final Color skin;
  final String gear;
  final Color gearColor;
  final String eyes;
  final String mouth;
  final String hair;
  final Color hairColor;

  const AvatarKonfiguration({
    this.bg = const Color(0xFFF4DCC7),
    this.skin = const Color(0xFFF6D3B2),
    this.gear = 'helmet',
    this.gearColor = const Color(0xFFC62828),
    this.eyes = 'happy',
    this.mouth = 'grin',
    this.hair = 'none',
    this.hairColor = const Color(0xFF3E2B22),
  });

  AvatarKonfiguration copyWith({
    Color? bg,
    Color? skin,
    String? gear,
    Color? gearColor,
    String? eyes,
    String? mouth,
    String? hair,
    Color? hairColor,
  }) =>
      AvatarKonfiguration(
        bg: bg ?? this.bg,
        skin: skin ?? this.skin,
        gear: gear ?? this.gear,
        gearColor: gearColor ?? this.gearColor,
        eyes: eyes ?? this.eyes,
        mouth: mouth ?? this.mouth,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
      );

  /// Der Text, der in `profiles.avatar` landet.
  ///
  /// `schluessel=wert;…` statt fester Reihenfolge, damit ein neunter Wert
  /// später nur ein zusätzliches Paar ist und keine Migration: Alte Clients
  /// überlesen ihn, neue Server-Zeilen bleiben lesbar.
  String get kodiert => [
        'bg=${_hex(bg)}',
        'skin=${_hex(skin)}',
        'gear=$gear',
        'gc=${_hex(gearColor)}',
        'eyes=$eyes',
        'mouth=$mouth',
        'hair=$hair',
        'hc=${_hex(hairColor)}',
      ].join(';');

  /// Liest den gespeicherten Text.
  ///
  /// Fällt bei jedem unbekannten oder kaputten Einzelwert auf den Standard
  /// zurück, statt aufzugeben: Ein Avatar ist Schmuck. Ein halb gelesener
  /// Kopf ist besser als ein Fehlerdialog vor dem Gesicht.
  static AvatarKonfiguration dekodiert(String? text) {
    if (text == null || text.trim().isEmpty) return const AvatarKonfiguration();
    const standard = AvatarKonfiguration();
    final werte = <String, String>{};
    for (final paar in text.split(';')) {
      final i = paar.indexOf('=');
      if (i <= 0) continue;
      werte[paar.substring(0, i).trim()] = paar.substring(i + 1).trim();
    }
    String auswahl(String key, List<String> erlaubt, String fallback) {
      final v = werte[key];
      return v != null && erlaubt.contains(v) ? v : fallback;
    }

    return AvatarKonfiguration(
      bg: _farbe(werte['bg']) ?? standard.bg,
      skin: _farbe(werte['skin']) ?? standard.skin,
      gear: auswahl('gear', kAvatarGears, standard.gear),
      gearColor: _farbe(werte['gc']) ?? standard.gearColor,
      eyes: auswahl('eyes', kAvatarEyes, standard.eyes),
      mouth: auswahl('mouth', kAvatarMouths, standard.mouth),
      hair: auswahl('hair', kAvatarHair, standard.hair),
      hairColor: _farbe(werte['hc']) ?? standard.hairColor,
    );
  }

  static String _hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

  static Color? _farbe(String? hex) {
    if (hex == null) return null;
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length != 6) return null;
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(0xFF000000 | n);
  }

  /// ⚠️ Feldweise, NICHT über [kodiert]. Der Unterschied ist keine
  /// Geschmacksfrage: Vergleicht die Gleichheit den kodierten Text, dann
  /// sind zwei Köpfe, deren Unterschied gar nicht erst kodiert wird,
  /// definitionsgemäß gleich — und jeder Rundlauf-Test bleibt grün, obwohl
  /// beim Speichern ein Wert verlorengeht. Genau das ist in der Gegenprobe
  /// zu dieser Datei passiert.
  @override
  bool operator ==(Object other) =>
      other is AvatarKonfiguration &&
      other.bg == bg &&
      other.skin == skin &&
      other.gear == gear &&
      other.gearColor == gearColor &&
      other.eyes == eyes &&
      other.mouth == mouth &&
      other.hair == hair &&
      other.hairColor == hairColor;

  @override
  int get hashCode =>
      Object.hash(bg, skin, gear, gearColor, eyes, mouth, hair, hairColor);
}

/// Eine fertige Vorlage aus dem Entwurf: Kopf plus Katalog-Beschriftung.
///
/// ⚠️ [name] ist der Name des AVATARS, nicht der der Person. Eine Vorlage
/// anzutippen ändert deshalb nur das Aussehen — sonst stünde nachher
/// „Bratwurst-Brigitte" in der Nutzerverwaltung, und der Kommandant dürfte
/// es geradeziehen.
class AvatarVorlage {
  final String name;
  final String rolle;
  final AvatarKonfiguration kopf;

  const AvatarVorlage(this.name, this.rolle, this.kopf);
}

class _Rolle {
  final String rolle;
  final String gear;
  final int helm;
  final List<String> namen;
  const _Rolle(this.rolle, this.gear, this.helm, this.namen);
}

const _rollen = [
  _Rolle('Atemschutz', 'scba', 0,
      ['Maskus Maximus', 'Flaschen-Franz', 'Luft-Lena', 'Tief-Atem-Toni']),
  _Rolle('Maschinist', 'helmet', 1,
      ['Pumpen-Peter', 'Druck-Doris', 'Kupplungs-Kurt', 'Saugkorb-Sabine']),
  _Rolle('Gruppenführer', 'visor', 2,
      ['Lage-Lotte', 'Chef vom Dienst', 'Melde-Meister', 'Einweis-Egon']),
  _Rolle('Jugendfeuerwehr', 'cap', 0,
      ['Mini-Löscher', 'Knoten-König', 'Schlauch-Sprinter', 'Jugend-Jette']),
  _Rolle('Drehleiter', 'helmet', 3,
      ['Höhen-Harry', 'Korb-Kalle', 'Leiter-Lisa', 'Aufstell-Achim']),
  _Rolle('Funker', 'helmet', 1,
      ['Kanal-Kai', 'Rausch-Rita', 'Melder-Momo', 'Antennen-Adi']),
  _Rolle('Dalmatiner', 'dog', 0,
      ['Flecki', 'Punkti', 'Waldi Wasserwerfer', 'Bello Blaulicht']),
  _Rolle('Grill & Kaffee', 'cap', 3,
      ['Grill-Gustav', 'Kaffee-Kalle', 'Bratwurst-Brigitte', 'Zwei-Zucker-Zenz']),
  _Rolle('Kameradschaft', 'helmet', 2,
      ['Immer-da-Ingo', 'Spätschicht-Sven', 'Übungs-Uschi', 'Ehren-Erwin']),
];

/// Die 36 Köpfe der Mannschaft — neun Rollen mal vier.
///
/// Die Rechnung stammt Zeichen für Zeichen aus dem Entwurf. Sie sieht
/// willkürlich aus und ist es auch: Sie streut Farben und Gesichter so, dass
/// keine zwei Nachbarn gleich aussehen. Sie hier nachzubauen statt „schöner"
/// zu machen ist Absicht — sonst steht in der App eine andere Mannschaft als
/// im Entwurf, und niemand kann mehr abgleichen.
final List<AvatarVorlage> kAvatarVorlagen = () {
  final out = <AvatarVorlage>[];
  for (var ri = 0; ri < _rollen.length; ri++) {
    final r = _rollen[ri];
    for (var vi = 0; vi < r.namen.length; vi++) {
      final k = ri * 4 + vi;
      final istHund = r.gear == 'dog';
      out.add(AvatarVorlage(
        r.namen[vi],
        r.rolle,
        AvatarKonfiguration(
          gear: r.gear,
          gearColor: kAvatarGearColors[(r.helm + vi) % kAvatarGearColors.length],
          bg: kAvatarBgs[(k * 5 + ri) % kAvatarBgs.length],
          skin: istHund
              ? const Color(0xFFFFFFFF)
              : kAvatarSkins[(k + vi) % kAvatarSkins.length],
          hairColor: istHund
              ? const Color(0xFF2B2320)
              : kAvatarHairColors[(k + ri) % kAvatarHairColors.length],
          eyes: istHund ? 'dots' : kAvatarEyes[(k + 2 * vi) % kAvatarEyes.length],
          mouth:
              istHund ? 'tongue' : kAvatarMouths[(k + ri) % kAvatarMouths.length],
          hair: istHund || r.gear == 'scba'
              ? 'none'
              : kAvatarHair[(k * 3 + vi) % kAvatarHair.length],
        ),
      ));
    }
  }
  return List<AvatarVorlage>.unmodifiable(out);
}();

/// Ein zufälliger Kopf für „Würfeln".
///
/// Würfelt über die Vorlagen-Rollen, nicht über alle acht Werte einzeln:
/// Freies Würfeln erzeugt Atemschutzmasken mit Vollbart darunter.
AvatarKonfiguration wuerfleAvatar(int Function(int) naechste) {
  final vorlage = kAvatarVorlagen[naechste(kAvatarVorlagen.length)];
  final k = vorlage.kopf;
  final istHund = k.gear == 'dog';
  return k.copyWith(
    bg: kAvatarBgs[naechste(kAvatarBgs.length)],
    gearColor: kAvatarGearColors[naechste(kAvatarGearColors.length)],
    skin: istHund ? k.skin : kAvatarSkins[naechste(kAvatarSkins.length)],
    hairColor:
        istHund ? k.hairColor : kAvatarHairColors[naechste(kAvatarHairColors.length)],
    eyes: istHund ? k.eyes : kAvatarEyes[naechste(kAvatarEyes.length)],
    mouth: istHund ? k.mouth : kAvatarMouths[naechste(kAvatarMouths.length)],
    hair: istHund || k.gear == 'scba'
        ? 'none'
        : kAvatarHair[naechste(kAvatarHair.length)],
  );
}
