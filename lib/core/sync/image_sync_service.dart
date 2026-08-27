/// image_sync_service.dart – Uploads local images to central Supabase storage
/// buckets. Images are downscaled and recompressed on the client so a bucket
/// only ever holds small JPEGs; the stored path then becomes a
/// `supabase://<bucket>/<object>` marker that resolves on every device (see
/// image_utils.dart).
library;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:fwapp/core/images/image_processing.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kEquipmentImagesBucket = 'equipment-images';

/// Kopfbilder der Gesamtwehr (#57 P5). Eigener Bucket, weil das Schreibrecht
/// ein anderes ist: Gerätefotos darf jeder Gerätewart pflegen, den Auftritt der
/// Wehr nur ihr Feuerwehrkommandant. Der Ordner IST die Gesamtwehr — die
/// Storage-Policies lesen sie aus dem ersten Pfadsegment.
const kBrandingBucket = 'gesamtwehr-branding';


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
  }) =>
      _hochladen(
        bucket: kEquipmentImagesBucket,
        // Timestamped name: each upload gets a fresh cache identity, so stale
        // caches on member devices can never mask a newer photo.
        object: 'eq_${equipmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
        previousPath: previousPath,
      );

  /// Foto eines Geräteraums (Issue #181).
  ///
  /// Derselbe Bucket wie die Gerätefotos, weil das Schreibrecht dasselbe ist:
  /// der Gerätewart. Ein eigener Bucket hätte dieselben vier Policies
  /// gebraucht und nichts getrennt, was zu trennen wäre.
  ///
  /// Das Präfix `co_` unterscheidet die Objekte trotzdem — sonst wäre am
  /// Namen nicht zu sehen, ob ein verwaistes Bild zu einem Gerät oder einem
  /// Fach gehörte.
  Future<String> uploadCompartmentImageBytes({
    required int compartmentId,
    required Uint8List bytes,
    String? previousPath,
  }) =>
      _hochladen(
        bucket: kEquipmentImagesBucket,
        object:
            'co_${compartmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
        previousPath: previousPath,
      );

  /// Kopfbild einer Gesamtwehr (#57 P5).
  ///
  /// Der Objektname MUSS mit der Gesamtwehr-ID als eigenem Pfadsegment
  /// beginnen — daran hängen die Storage-Policies. Ein Name ohne diesen Ordner
  /// wird vom Server abgelehnt, nicht etwa still an der falschen Stelle
  /// abgelegt.
  Future<String> uploadBrandingImage({
    required String gesamtwehrId,
    required Uint8List bytes,
    String? previousPath,
  }) =>
      _hochladen(
        bucket: kBrandingBucket,
        object: '$gesamtwehrId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
        previousPath: previousPath,
      );

  /// Gemeinsamer Weg: verkleinern, hochladen, Vorgänger best-effort aufräumen,
  /// Marker zurückgeben.
  Future<String> _hochladen({
    required String bucket,
    required String object,
    required Uint8List bytes,
    String? previousPath,
  }) async {
    final jpeg = await compute(compressImageForUpload, bytes);
    await client.storage.from(bucket).uploadBinary(
          object,
          jpeg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    // Nur aufräumen, was wirklich in DIESEM Bucket liegt — siehe
    // [objektImBucket].
    final vorgaenger = objektImBucket(previousPath, bucket);
    if (vorgaenger != null) {
      try {
        await client.storage.from(bucket).remove([vorgaenger]);
      } catch (_) {
        // Orphaned object only — the new image is already in place.
      }
    }

    return '$kSupabaseImagePrefix$bucket/$object';
  }
}
