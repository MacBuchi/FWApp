/// avatar_konfiguration_test.dart – Der Avatar als Text (Issue #100).
///
/// Zwei Aussagen tragen hier alles:
/// 1. Was gespeichert wird, kommt unverändert zurück — sonst ändert sich das
///    Gesicht beim nächsten Anmelden von selbst.
/// 2. Was gespeichert wird, kommt am SERVER an. Die RPC `mein_profil_setzen`
///    weist alles ab, was länger als 200 Zeichen ist oder Zeichen außerhalb
///    von `[A-Za-z0-9=;#_-]` enthält. Die Regel steht in SQL, die Erzeugung
///    in Dart — dieser Test ist die einzige Stelle, an der beide aufeinander
///    treffen.
library;

import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';

/// Die Zeichen-Regel aus 20260804140000_profil_anzeigename_avatar.sql.
final _serverRegel = RegExp(r'^[A-Za-z0-9=;#_-]+$');

void main() {
  group('kodieren und wieder lesen', () {
    test('ein vollständig gesetzter Kopf überlebt die Runde', () {
      const kopf = AvatarKonfiguration(
        bg: Color(0xFFCBDCEA),
        skin: Color(0xFF8D5524),
        gear: 'scba',
        gearColor: Color(0xFFE8B33C),
        eyes: 'shades',
        mouth: 'whistle',
        hair: 'walrus',
        hairColor: Color(0xFFC9BCAE),
      );
      expect(AvatarKonfiguration.dekodiert(kopf.kodiert), kopf);
    });

    test('jede Vorlage überlebt die Runde', () {
      for (final v in kAvatarVorlagen) {
        expect(
          AvatarKonfiguration.dekodiert(v.kopf.kodiert),
          v.kopf,
          reason: v.name,
        );
      }
    });

    test('jeder der acht Werte steht wirklich im Text', () {
      // Der Rundlauf allein beweist das NICHT: Wird ein Wert gar nicht erst
      // kodiert, liest ihn auch niemand falsch zurück — er ist einfach weg,
      // und beim nächsten Anmelden steht der Standard da. (Genau so blieb
      // die erste Gegenprobe zu dieser Datei fälschlich grün.)
      const standard = AvatarKonfiguration();
      final anders = standard.copyWith(
        bg: kAvatarBgs[2],
        skin: kAvatarSkins[3],
        gear: 'cap',
        gearColor: kAvatarGearColors[1],
        eyes: 'wink',
        mouth: 'laugh',
        hair: 'walrus',
        hairColor: kAvatarHairColors[2],
      );
      // Acht Änderungen, acht Unterschiede im Text — jede einzeln geprüft,
      // damit der Fehlschlag benennt, welcher Wert fehlt.
      for (final (name, geaendert) in <(String, AvatarKonfiguration)>[
        ('Hintergrund', standard.copyWith(bg: anders.bg)),
        ('Hautton', standard.copyWith(skin: anders.skin)),
        ('Kopfbedeckung', standard.copyWith(gear: anders.gear)),
        ('Helmfarbe', standard.copyWith(gearColor: anders.gearColor)),
        ('Augen', standard.copyWith(eyes: anders.eyes)),
        ('Mund', standard.copyWith(mouth: anders.mouth)),
        ('Bart', standard.copyWith(hair: anders.hair)),
        ('Haarfarbe', standard.copyWith(hairColor: anders.hairColor)),
      ]) {
        expect(geaendert.kodiert, isNot(standard.kodiert), reason: name);
        expect(AvatarKonfiguration.dekodiert(geaendert.kodiert), geaendert,
            reason: name);
      }
    });

    test('ohne Text kommt der Standardkopf', () {
      expect(AvatarKonfiguration.dekodiert(null),
          const AvatarKonfiguration());
      expect(AvatarKonfiguration.dekodiert('   '),
          const AvatarKonfiguration());
    });
  });

  group('kaputte Werte kosten nur diesen einen Wert', () {
    test('ein unbekannter Schlüssel wird überlesen', () {
      const kopf = AvatarKonfiguration(gear: 'cap');
      final mitZukunft = '${kopf.kodiert};brille=rund';
      expect(AvatarKonfiguration.dekodiert(mitZukunft), kopf);
    });

    test('ein unbekannter Wert fällt auf den Standard zurück, der Rest '
        'bleibt stehen', () {
      final gelesen =
          AvatarKonfiguration.dekodiert('gear=raumanzug;eyes=dots;hair=beard');
      expect(gelesen.gear, 'helmet'); // Standard
      expect(gelesen.eyes, 'dots'); // unverändert übernommen
      expect(gelesen.hair, 'beard');
    });

    test('eine kaputte Farbe fällt auf den Standard zurück', () {
      final gelesen = AvatarKonfiguration.dekodiert('bg=ZZZZZZ;skin=8D5524');
      expect(gelesen.bg, const AvatarKonfiguration().bg);
      expect(gelesen.skin, const Color(0xFF8D5524));
    });

    test('reiner Unsinn ergibt den Standardkopf statt einer Ausnahme', () {
      expect(AvatarKonfiguration.dekodiert('%%%kein=;;;avatar'),
          const AvatarKonfiguration());
    });

    test('eine Farbe mit Raute wird auch gelesen', () {
      expect(AvatarKonfiguration.dekodiert('bg=#CBDCEA').bg,
          const Color(0xFFCBDCEA));
    });
  });

  group('die Grenzen des Servers', () {
    test('jede Vorlage passt in Länge und Zeichenvorrat der RPC', () {
      for (final v in kAvatarVorlagen) {
        final text = v.kopf.kodiert;
        expect(text.length, lessThanOrEqualTo(200), reason: v.name);
        expect(_serverRegel.hasMatch(text), isTrue,
            reason: '${v.name}: $text');
      }
    });

    test('auch jede einzelne Auswahl des Baukastens passt', () {
      var kopf = const AvatarKonfiguration();
      for (final g in kAvatarGears) {
        for (final e in kAvatarEyes) {
          for (final m in kAvatarMouths) {
            for (final h in kAvatarHair) {
              kopf = kopf.copyWith(gear: g, eyes: e, mouth: m, hair: h);
              expect(kopf.kodiert.length, lessThanOrEqualTo(200));
              expect(_serverRegel.hasMatch(kopf.kodiert), isTrue,
                  reason: kopf.kodiert);
            }
          }
        }
      }
      // Und mit den längsten Farbwerten obendrauf.
      final voll = kopf.copyWith(
        bg: kAvatarBgs.last,
        skin: kAvatarSkins.last,
        gearColor: kAvatarGearColors.last,
        hairColor: kAvatarHairColors.last,
      );
      expect(voll.kodiert.length, lessThanOrEqualTo(200));
    });
  });

  group('die Mannschaft', () {
    test('sind 36 Köpfe in neun Rollen', () {
      expect(kAvatarVorlagen, hasLength(36));
      expect(kAvatarVorlagen.map((v) => v.rolle).toSet(), hasLength(9));
    });

    test('jeder Kopf trägt nur bekannte Werte', () {
      for (final v in kAvatarVorlagen) {
        expect(kAvatarGears, contains(v.kopf.gear), reason: v.name);
        expect(kAvatarEyes, contains(v.kopf.eyes), reason: v.name);
        expect(kAvatarMouths, contains(v.kopf.mouth), reason: v.name);
        expect(kAvatarHair, contains(v.kopf.hair), reason: v.name);
      }
    });

    test('unter der Atemschutzmaske und beim Dalmatiner wächst kein Bart', () {
      for (final v in kAvatarVorlagen) {
        if (v.kopf.gear == 'scba' || v.kopf.gear == 'dog') {
          expect(v.kopf.hair, 'none', reason: v.name);
        }
      }
    });

    test('keine zwei Köpfe sehen gleich aus', () {
      final gesichter = kAvatarVorlagen.map((v) => v.kopf.kodiert).toSet();
      expect(gesichter, hasLength(kAvatarVorlagen.length));
    });

    test('jeder Name kommt genau einmal vor', () {
      final namen = kAvatarVorlagen.map((v) => v.name).toSet();
      expect(namen, hasLength(kAvatarVorlagen.length));
    });
  });

  group('würfeln', () {
    test('trifft nur bekannte Werte — auch bei jedem Index', () {
      // Der Würfel wird durchgezählt statt zufällig gezogen: Ein Test, der
      // nur „meistens" prüft, ist bei genau diesem Kombinationsproblem der
      // schwächere.
      for (var i = 0; i < 40; i++) {
        final kopf = wuerfleAvatar((n) => i % n);
        expect(kAvatarGears, contains(kopf.gear));
        expect(kAvatarEyes, contains(kopf.eyes));
        expect(kAvatarMouths, contains(kopf.mouth));
        expect(kAvatarHair, contains(kopf.hair));
      }
    });

    test('würfelt niemandem einen Bart unter die Atemschutzmaske', () {
      for (var i = 0; i < 40; i++) {
        final kopf = wuerfleAvatar((n) => i % n);
        if (kopf.gear == 'scba' || kopf.gear == 'dog') {
          expect(kopf.hair, 'none');
        }
      }
    });

    test('der Dalmatiner behält sein Fell und seine Schnauze', () {
      for (var i = 0; i < 40; i++) {
        final kopf = wuerfleAvatar((n) => i % n);
        if (kopf.gear == 'dog') {
          expect(kopf.skin, const Color(0xFFFFFFFF));
          expect(kopf.eyes, 'dots');
          expect(kopf.mouth, 'tongue');
        }
      }
    });
  });
}
