/// resolve_image_test.dart – Was `resolveImage` aus einem `supabase://`-Marker
/// baut (Issue #114): richtige URL, stabiler Cache-Schlüssel und vor allem die
/// Kopfzeilen, ohne die der private Bucket nichts herausgibt.
library;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/utils/image_utils.dart';

const _marker = 'supabase://equipment-images/eq_7_1700.jpg';

void main() {
  setUp(() {
    supabaseStorageBaseUrl = 'https://fwapp-api.example';
    supabaseStorageHeaders = () => {
          'apikey': 'anon-schluessel',
          'Authorization': 'Bearer sitzungs-token',
        };
  });

  tearDown(() {
    supabaseStorageBaseUrl = null;
    supabaseStorageHeaders = null;
  });

  Future<CachedNetworkImage> baue(WidgetTester tester, String pfad) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: resolveImage(path: pfad, width: 100, height: 100)),
    ));
    return tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
  }

  testWidgets('der Marker wird zur URL des privaten Buckets', (tester) async {
    final bild = await baue(tester, _marker);
    expect(
      bild.imageUrl,
      'https://fwapp-api.example/storage/v1/object/authenticated/'
      'equipment-images/eq_7_1700.jpg',
    );
  });

  testWidgets('der Cache-Schlüssel bleibt der Marker, nicht die URL',
      (tester) async {
    // Sonst verfiele der Vorrat bei jedem Serverumzug — und der Precache
    // legt seine Einträge unter genau diesem Schlüssel ab.
    final bild = await baue(tester, _marker);
    expect(bild.cacheKey, _marker);
  });

  testWidgets('die Kopfzeilen hängen dran — ohne sie gibt der Bucket nichts '
      'heraus', (tester) async {
    // ⚠️ Hälfte eins von Issue #114. Hälfte zwei ist der Renderweg
    // (`ImageRenderMethodForWeb.HttpGet`); der lässt sich hier NICHT prüfen,
    // weil er nur in der Web-Fassung des Pakets ausgewertet wird und Tests auf
    // der VM laufen. Dafür ist der Durchklick im Browser der Beweis — siehe
    // AGENTS.md.
    final bild = await baue(tester, _marker);
    expect(bild.httpHeaders, isNotNull);
    expect(bild.httpHeaders!['apikey'], 'anon-schluessel');
    expect(bild.httpHeaders!['Authorization'], 'Bearer sitzungs-token');
  });

  testWidgets('ohne angemeldete Sitzung bleibt wenigstens der Schlüssel',
      (tester) async {
    supabaseStorageHeaders = () => {'apikey': 'anon-schluessel'};
    final bild = await baue(tester, _marker);
    expect(bild.httpHeaders!.containsKey('Authorization'), isFalse);
    expect(bild.httpHeaders!['apikey'], 'anon-schluessel');
  });

  testWidgets('ohne konfigurierten Server wird gar nicht erst geladen',
      (tester) async {
    supabaseStorageBaseUrl = null;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: resolveImage(path: _marker, width: 100, height: 100)),
    ));
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
