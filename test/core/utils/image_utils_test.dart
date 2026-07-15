/// image_utils_test.dart – resolveImage() widget dispatch (M2).
library;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/utils/image_utils.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  tearDown(() {
    supabaseStorageBaseUrl = null;
    supabaseStorageHeaders = null;
  });

  testWidgets('asset paths render Image.asset', (tester) async {
    await tester.pumpWidget(host(resolveImage(
        path: 'assets/images/placeholder_equipment.png',
        width: 100,
        height: 100)));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('http URLs render CachedNetworkImage', (tester) async {
    await tester.pumpWidget(host(resolveImage(
        path: 'http://server/img.jpg', width: 100, height: 100)));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('supabase marker renders CachedNetworkImage when configured',
      (tester) async {
    supabaseStorageBaseUrl = 'http://192.168.178.201:8000';
    await tester.pumpWidget(host(resolveImage(
        path: 'supabase://equipment-images/eq_1_1.jpg',
        width: 100,
        height: 100)));

    final widget = tester
        .widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(widget.imageUrl, contains('/storage/v1/object/authenticated/'));
    // Cache key is the marker so cached entries survive a server move.
    expect(widget.cacheKey, 'supabase://equipment-images/eq_1_1.jpg');
  });

  testWidgets('supabase marker falls back to placeholder in local mode',
      (tester) async {
    await tester.pumpWidget(host(resolveImage(
        path: 'supabase://equipment-images/eq_1_1.jpg',
        width: 100,
        height: 100)));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.fire_truck), findsOneWidget);
  });

  testWidgets('null path renders the placeholder', (tester) async {
    await tester
        .pumpWidget(host(resolveImage(path: null, width: 100, height: 100)));
    expect(find.byIcon(Icons.fire_truck), findsOneWidget);
  });
}
