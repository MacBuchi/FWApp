/// image_sync_service_test.dart – Upload compression and path/marker logic (M2).
library;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/image_sync_service.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:image/image.dart' as img;

/// Noise compresses worst-case — if this fits the budget, real photos do too.
Uint8List _noiseImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 42;
  for (final pixel in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixel.setRgb(seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
  }
  return img.encodePng(image);
}

void main() {
  group('compressImageForUpload', () {
    test('shrinks a large noisy image below the size and dimension budget',
        () {
      final result = compressImageForUpload(_noiseImage(2400, 1600));

      expect(result.length, lessThanOrEqualTo(kMaxImageBytes));
      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, lessThanOrEqualTo(kMaxImageDimension));
      expect(decoded.height, lessThanOrEqualTo(kMaxImageDimension));
      // Aspect ratio preserved (2400:1600 = 3:2).
      expect((decoded.width / decoded.height - 1.5).abs(), lessThan(0.01));
    });

    test('keeps small images at their dimensions', () {
      final result = compressImageForUpload(_noiseImage(200, 150));

      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, 200);
      expect(decoded.height, 150);
      expect(result.length, lessThanOrEqualTo(kMaxImageBytes));
    });

    test('portrait orientation uses the height as the longest side', () {
      final result = compressImageForUpload(_noiseImage(1200, 2400));

      final decoded = img.decodeJpg(result)!;
      expect(decoded.height, kMaxImageDimension);
      expect(decoded.width, kMaxImageDimension ~/ 2);
    });

    test('rejects data that is not an image', () {
      expect(() => compressImageForUpload(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });

  group('image path classification', () {
    test('isLocalImagePath: only device-file paths count as local', () {
      expect(isLocalImagePath('/var/mobile/media/IMG_1.jpg'), isTrue);
      expect(isLocalImagePath('C:/photos/a.png'), isTrue);
      expect(isLocalImagePath('assets/images/equipment/haligan.png'), isFalse);
      expect(isLocalImagePath('supabase://equipment-images/eq_1_2.jpg'),
          isFalse);
      expect(isLocalImagePath('http://server/img.jpg'), isFalse);
      expect(isLocalImagePath('https://server/img.jpg'), isFalse);
      expect(isLocalImagePath(null), isFalse);
      expect(isLocalImagePath(''), isFalse);
    });

    test('isRemoteImagePath: markers and http(s) URLs', () {
      expect(isRemoteImagePath('supabase://equipment-images/x.jpg'), isTrue);
      expect(isRemoteImagePath('https://server/img.jpg'), isTrue);
      expect(isRemoteImagePath('assets/images/x.png'), isFalse);
      expect(isRemoteImagePath('/local/file.jpg'), isFalse);
      expect(isRemoteImagePath(null), isFalse);
    });
  });

  group('supabaseImageUrl', () {
    tearDown(() => supabaseStorageBaseUrl = null);

    test('resolves a marker against the configured server', () {
      supabaseStorageBaseUrl = 'http://192.168.178.201:8000';
      expect(
        supabaseImageUrl('supabase://equipment-images/eq_7_123.jpg'),
        'http://192.168.178.201:8000/storage/v1/object/authenticated/'
        'equipment-images/eq_7_123.jpg',
      );
    });

    test('returns null without a configured server or for non-markers', () {
      expect(supabaseImageUrl('supabase://equipment-images/x.jpg'), isNull);
      supabaseStorageBaseUrl = 'http://server';
      expect(supabaseImageUrl('/local/file.jpg'), isNull);
    });
  });
}
