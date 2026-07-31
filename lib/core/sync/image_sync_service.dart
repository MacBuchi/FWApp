/// image_sync_service.dart – Uploads local equipment photos to the central
/// Supabase storage bucket (M2). Images are downscaled and recompressed on
/// the client so the bucket only ever holds small JPEGs; imagePath then
/// becomes a `supabase://equipment-images/<object>` marker that resolves on
/// every device (see image_utils.dart).
library;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:fwapp/core/images/image_processing.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kEquipmentImagesBucket = 'equipment-images';


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
  }) async =>
      uploadEquipmentImageBytes(
        equipmentId: equipmentId,
        bytes: await XFile(localPath).readAsBytes(),
        previousPath: previousPath,
      );

  /// Wie [uploadEquipmentImage], nimmt das Bild aber direkt als Bytes.
  ///
  /// Das ist der Weg für die zugeschnittenen Bilder aus der Bildaufnahme
  /// (Issue #56): Der Zuschnitt existiert nur im Speicher, und in der Web-App
  /// gibt es ohnehin keinen Dateipfad, den man weiterreichen könnte.
  Future<String> uploadEquipmentImageBytes({
    required int equipmentId,
    required Uint8List bytes,
    String? previousPath,
  }) async {
    final jpeg = await compute(compressImageForUpload, bytes);
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
