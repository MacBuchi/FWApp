/// branding_test.dart – Kopfbereich der Gesamtwehr (#57 P5): Modell,
/// Zwischenspeicher-Format, Bucket-Trennung und die Frage, wer pflegen darf.
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/branding_providers.dart';
import 'package:fwapp/core/sync/image_sync_service.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/home/presentation/widgets/gesamtwehr_header.dart';

const _gw = '11111111-1111-1111-1111-111111111111';
const _andereGw = '22222222-2222-2222-2222-222222222222';

void main() {
  group('GesamtwehrBranding', () {
    test('istLeer erkennt den ungepflegten Zustand', () {
      expect(const GesamtwehrBranding(gesamtwehrId: _gw).istLeer, isTrue);
      expect(
        const GesamtwehrBranding(gesamtwehrId: _gw, titel: '', willkommenstext: '')
            .istLeer,
        isTrue,
      );
      expect(
        const GesamtwehrBranding(gesamtwehrId: _gw, willkommenstext: 'Moin')
            .istLeer,
        isFalse,
      );
      expect(
        const GesamtwehrBranding(
                gesamtwehrId: _gw,
                bildPfad: 'supabase://gesamtwehr-branding/$_gw/1.jpg')
            .istLeer,
        isFalse,
      );
    });

    test('ohne eigenen Titel steht der Name der Gesamtwehr im Kopf', () {
      const ohne = GesamtwehrBranding(gesamtwehrId: _gw);
      expect(ohne.anzeigeTitel('Gesamtfeuerwehr Musterstadt'),
          'Gesamtfeuerwehr Musterstadt');
      const mit = GesamtwehrBranding(gesamtwehrId: _gw, titel: 'Unsere Wehr');
      expect(mit.anzeigeTitel('Gesamtfeuerwehr Musterstadt'), 'Unsere Wehr');
      // Leerer Titel ist kein Titel — sonst stünde eine leere Zeile im Bild.
      const leer = GesamtwehrBranding(gesamtwehrId: _gw, titel: '');
      expect(leer.anzeigeTitel('Gesamtfeuerwehr Musterstadt'),
          'Gesamtfeuerwehr Musterstadt');
    });

    test('überlebt den Weg durch den Zwischenspeicher unverändert', () {
      const original = GesamtwehrBranding(
        gesamtwehrId: _gw,
        titel: 'Freiwillige Feuerwehr',
        willkommenstext: 'Übung am Dienstag, 19 Uhr.',
        bildPfad: 'supabase://gesamtwehr-branding/$_gw/1700.jpg',
      );
      final zurueck = GesamtwehrBranding.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(zurueck, isNotNull);
      expect(zurueck!.gesamtwehrId, original.gesamtwehrId);
      expect(zurueck.titel, original.titel);
      expect(zurueck.willkommenstext, original.willkommenstext);
      expect(zurueck.bildPfad, original.bildPfad);
    });

    test('eine Zeile ohne Gesamtwehr-Id ist kein Kopfbereich', () {
      expect(GesamtwehrBranding.fromJson(const {'title': 'X'}), isNull);
    });

    test('jede Wehr hat ihren eigenen Schlüssel im Zwischenspeicher', () {
      expect(brandingPrefsKey(_gw), isNot(brandingPrefsKey(_andereGw)));
    });
  });

  group('gesamtwehrKopfHoehe', () {
    test('auf hohen Fenstern gilt die Obergrenze', () {
      expect(gesamtwehrKopfHoehe(900), kGesamtwehrHeaderBildHoehe);
      expect(gesamtwehrKopfHoehe(683), kGesamtwehrHeaderBildHoehe);
      expect(gesamtwehrKopfHoehe(560), kGesamtwehrHeaderBildHoehe);
    });

    test('auf niedrigen Fenstern schrumpft der Kopf', () {
      // 683×411 im Querformat: Mit fester Höhe stand die ganze Startseite
      // unter der Kante (Browser-Befund).
      expect(gesamtwehrKopfHoehe(411), lessThan(kGesamtwehrHeaderBildHoehe));
      expect(gesamtwehrKopfHoehe(411), closeTo(123.3, 0.1));
    });

    test('aber nie unter eine erkennbare Höhe', () {
      expect(gesamtwehrKopfHoehe(200), 96);
      expect(gesamtwehrKopfHoehe(0), 96);
    });
  });

  group('objektImBucket', () {
    test('gibt den Objektnamen nur für den eigenen Bucket heraus', () {
      expect(
        objektImBucket(
            'supabase://gesamtwehr-branding/$_gw/1700.jpg', kBrandingBucket),
        '$_gw/1700.jpg',
      );
      expect(
        objektImBucket('supabase://equipment-images/eq_7_1.jpg',
            kEquipmentImagesBucket),
        'eq_7_1.jpg',
      );
    });

    test('ein Marker aus dem FREMDEN Bucket wird abgewiesen, nicht zerschnitten',
        () {
      // Der eigentliche Fehler: Wer nur „ist ein supabase://-Marker" prüft und
      // dann blind das eigene Präfix abschneidet, bekommt hier einen
      // verstümmelten Objektnamen zurück und löscht damit daneben.
      expect(
        objektImBucket('supabase://equipment-images/eq_7_1.jpg',
            kBrandingBucket),
        isNull,
      );
      expect(
        objektImBucket(
            'supabase://gesamtwehr-branding/$_gw/1.jpg', kEquipmentImagesBucket),
        isNull,
      );
    });

    test('nicht-Marker und null bleiben ohne Ergebnis', () {
      expect(objektImBucket(null, kBrandingBucket), isNull);
      expect(objektImBucket('/lokal/datei.jpg', kBrandingBucket), isNull);
      expect(objektImBucket('', kBrandingBucket), isNull);
    });
  });

  group('supabaseImageUrl für Kopfbilder', () {
    tearDown(() => supabaseStorageBaseUrl = null);

    test('der Ordner der Gesamtwehr bleibt Teil des Pfads', () {
      supabaseStorageBaseUrl = 'https://fwapp-api.example';
      expect(
        supabaseImageUrl('supabase://gesamtwehr-branding/$_gw/1700.jpg'),
        'https://fwapp-api.example/storage/v1/object/authenticated/'
        'gesamtwehr-branding/$_gw/1700.jpg',
      );
    });
  });

  group('darfBrandingPflegen', () {
    Future<bool> pruefe({
      GesamtwehrBezug? bezug,
      Set<String>? kommandiert,
    }) async {
      final container = ProviderContainer(overrides: [
        aktuelleGesamtwehrProvider.overrideWith((ref) async => bezug),
        meineKommandoGesamtwehrenProvider
            .overrideWith((ref) async => kommandiert),
      ]);
      addTearDown(container.dispose);
      return container.read(darfBrandingPflegenProvider.future);
    }

    test('der Feuerwehrkommandant dieser Wehr darf', () async {
      expect(
        await pruefe(
            bezug: const GesamtwehrBezug(id: _gw), kommandiert: const {_gw}),
        isTrue,
      );
    });

    test('der Kommandant einer ANDEREN Wehr darf hier nicht', () async {
      expect(
        await pruefe(
            bezug: const GesamtwehrBezug(id: _gw),
            kommandiert: const {_andereGw}),
        isFalse,
      );
    });

    test('ein Gerätewart ohne Kommando darf nicht', () async {
      expect(
        await pruefe(
            bezug: const GesamtwehrBezug(id: _gw), kommandiert: const {}),
        isFalse,
      );
    });

    test('ohne Gesamtwehr gibt es nichts zu pflegen', () async {
      expect(await pruefe(bezug: null, kommandiert: const {_gw}), isFalse);
    });

    test('auf einem Alt-Server (null) bleibt der Knopf weg', () async {
      expect(
        await pruefe(bezug: const GesamtwehrBezug(id: _gw), kommandiert: null),
        isFalse,
      );
    });
  });
}
