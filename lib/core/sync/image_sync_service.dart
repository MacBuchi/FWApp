/// image_sync_service.dart – Uploads local equipment photos to the central
/// Supabase storage bucket (M2). Images are downscaled and recompressed on
/// the client so the bucket only ever holds small JPEGs; imagePath then
/// becomes a `supabase://equipment-images/<object>` marker that resolves on
/// every device (see image_utils.dart).
library;
import 'dart:math';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

const kEquipmentImagesBucket = 'equipment-images';

/// Upload budget: longest side and encoded size the compressor aims for.
const kMaxImageDimension = 1024;
const kMaxImageBytes = 300 * 1024;

/// Decodes, downscales to [kMaxImageDimension] and re-encodes as JPEG,
/// stepping quality (and, if needed, size) down until the result fits
/// [kMaxImageBytes]. Top-level so it can run in a background isolate.
Uint8List compressImageForUpload(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null; // decoder threw on corrupt data — same outcome as null
  }
  var image = decoded;
  if (image == null) {
    throw const FormatException('Bildformat wird nicht unterstützt.');
  }
  image = img.bakeOrientation(image); // apply EXIF rotation before stripping

  var bytes = Uint8List(0);
  var dimension = kMaxImageDimension;
  while (true) {
    var scaled = image;
    if (max(image.width, image.height) > dimension) {
      scaled = img.copyResize(
        image,
        width: image.width >= image.height ? dimension : null,
        height: image.height > image.width ? dimension : null,
        interpolation: img.Interpolation.average,
      );
    }
    for (var quality = 85; quality >= 45; quality -= 10) {
      bytes = img.encodeJpg(scaled, quality: quality);
      if (bytes.length <= kMaxImageBytes) return bytes;
    }
    if (dimension <= 512) return bytes; // pathological input: best effort
    dimension = (dimension * 3) ~/ 4;
  }
}

class ImageSyncService {
  final SupabaseClient client;
  ImageSyncService(this.client);

  /// Uploads the local file at [localPath] and returns its supabase://
  /// marker. [previousPath] (the replaced photo's marker, if any) is removed
  /// from the bucket best-effort so replaced photos don't pile up.
  Future<String> uploadEquipmentImage({
    required int equipmentId,
    required String localPath,
    String? previousPath,
  }) async {
    final raw = await XFile(localPath).readAsBytes();
    final jpeg = await compute(compressImageForUpload, raw);
    // Timestamped name: each upload gets a fresh cache identity, so stale
    // caches on member devices can never mask a newer photo.
    final object =
        'eq_${equipmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from(kEquipmentImagesBucket).uploadBinary(
          object,
          jpeg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    if (isSupabaseImagePath(previousPath)) {
      final previousObject = previousPath!
          .substring('$kSupabaseImagePrefix$kEquipmentImagesBucket/'.length);
      try {
        await client.storage
            .from(kEquipmentImagesBucket)
            .remove([previousObject]);
      } catch (_) {
        // Orphaned object only — the new photo is already in place.
      }
    }

    return '$kSupabaseImagePrefix$kEquipmentImagesBucket/$object';
  }
}
