/// anhang_speicher.dart – Unterlagen am Fahrzeug: hochladen, herunterladen,
/// offline behalten (Issue #182).
///
/// **Die Offline-Zusage ist der Kern, nicht das Beiwerk.** Eine
/// Betriebsanleitung, die nur mit Netz lesbar ist, fehlt genau dann, wenn man
/// sie braucht — das Fahrzeug steht selten im WLAN des Gerätehauses.
/// Deshalb hält jeder Anhang zwei Adressen: [VehicleAttachmentData.storagePath]
/// (der Server, für alle) und [VehicleAttachmentData.localPath] (dieses
/// Gerät). Erst die zweite ist die Zusage.
///
/// **Der Bucket ist nach Abteilung geordnet.** Die Storage-Policies lesen die
/// Abteilung aus dem ersten Pfadsegment — ein Objektname ohne diesen Ordner
/// wird vom Server abgelehnt, nicht etwa still danebengelegt. Dasselbe
/// Muster wie beim Kopfbereich der Gesamtwehr.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kVehicleAttachmentsBucket = 'vehicle-attachments';

/// Was der Server annimmt (Migration 20260827060000). Die App prüft vorher,
/// damit ein zu großes PDF eine verständliche Meldung bekommt statt eines
/// Storage-Fehlers.
const kMaxAnhangBytes = 20 * 1024 * 1024;

const kErlaubteAnhangTypen = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
};

/// Bild oder Dokument? Entscheidet, ob die App den Anhang selbst zeigt oder
/// an den Betrachter des Geräts weiterreicht.
String anhangArt(String mimeType) =>
    mimeType.startsWith('image/') ? 'image' : 'document';

/// Rät den MIME-Typ aus der Endung. Der Dateiwähler liefert ihn auf manchen
/// Android-Fassungen nicht mit — dann ist die Endung alles, was da ist.
String mimeAusName(String dateiname) {
  switch (p.extension(dateiname).toLowerCase()) {
    case '.pdf':
      return 'application/pdf';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    default:
      return '';
  }
}

/// Der Anhang ließ sich nicht annehmen — mit einem Satz, der am Gerät
/// verständlich ist.
class AnhangAbgelehnt implements Exception {
  final String grund;
  const AnhangAbgelehnt(this.grund);
  @override
  String toString() => grund;
}

/// Legt Anhänge lokal ab und hält sie mit dem Server im Gleichstand.
///
/// [client] `null` heißt: reiner Lokalbetrieb. Anhänge bleiben dann auf
/// diesem Gerät und werden beim nächsten Sync nachgereicht — die App muss
/// ohne Server vollständig laufen (Architektur-Leitplanke).
class AnhangSpeicher {
  final AppDatabase db;
  final SupabaseClient? client;

  /// Wo die Kopien auf diesem Gerät liegen. Als Funktion injizierbar, damit
  /// Tests ein Wegwerf-Verzeichnis vorgeben können statt den echten
  /// Dokumentenordner zu beschreiben.
  final Future<Directory> Function() ordner;

  AnhangSpeicher({
    required this.db,
    this.client,
    Future<Directory> Function()? ordner,
  }) : ordner = ordner ?? getApplicationDocumentsDirectory;

  /// Nimmt eine Datei an: prüfen, lokal ablegen, Zeile schreiben, hochladen.
  ///
  /// Die Reihenfolge ist Absicht. Erst liegt die Datei lokal und in der
  /// Datenbank, dann geht sie zum Server — bricht der Upload ab, ist der
  /// Anhang trotzdem da und wird später nachgereicht. Andersherum wäre eine
  /// abgerissene Verbindung ein Datenverlust.
  Future<VehicleAttachmentData> hinzufuegen({
    required int vehicleId,
    required String dateiname,
    required Uint8List bytes,
    String? mimeType,
    String? abteilungId,
  }) async {
    final typ = (mimeType == null || mimeType.isEmpty)
        ? mimeAusName(dateiname)
        : mimeType;
    if (!kErlaubteAnhangTypen.contains(typ)) {
      throw const AnhangAbgelehnt(
          'Nur Bilder (JPG, PNG, WebP) und PDF-Dateien.');
    }
    if (bytes.length > kMaxAnhangBytes) {
      throw AnhangAbgelehnt('Die Datei ist zu groß — höchstens '
          '${kMaxAnhangBytes ~/ (1024 * 1024)} MB.');
    }

    final lokal = await _schreibeLokal(dateiname, bytes);
    final id = await db.attachmentDao.insertAttachment(
      VehicleAttachmentsCompanion.insert(
        vehicleId: vehicleId,
        title: p.basename(dateiname),
        kind: Value(anhangArt(typ)),
        mimeType: Value(typ),
        localPath: Value(lokal),
        sizeBytes: Value(bytes.length),
      ),
    );

    await _hochladen(id: id, bytes: bytes, typ: typ, abteilungId: abteilungId);
    return (await db.attachmentDao.getById(id))!;
  }

  /// Sorgt dafür, dass der Anhang auf diesem Gerät liegt, und gibt den Pfad
  /// zurück. `null` heißt: geht gerade nicht (kein Netz, kein Server).
  ///
  /// Das ist der Aufruf hinter „Für den Einsatz herunterladen" und hinter
  /// jedem Öffnen: Wer einen Anhang einmal angesehen hat, hat ihn danach
  /// auch ohne Netz.
  Future<String?> sicherstellenLokal(VehicleAttachmentData anhang) async {
    final vorhanden = anhang.localPath;
    if (vorhanden != null && !kIsWeb && File(vorhanden).existsSync()) {
      return vorhanden;
    }
    final marker = anhang.storagePath;
    final c = client;
    if (marker == null || c == null || kIsWeb) return null;

    final objekt = objektImBucket(marker, kVehicleAttachmentsBucket);
    if (objekt == null) return null;
    try {
      final bytes =
          await c.storage.from(kVehicleAttachmentsBucket).download(objekt);
      final pfad = await _schreibeLokal(anhang.title, bytes);
      await db.attachmentDao.setLocalPath(anhang.id, pfad);
      return pfad;
    } catch (e) {
      appLog.w('Anhang ${anhang.id} nicht ladbar', error: e);
      return null;
    }
  }

  /// Entfernt den Anhang überall: Gerät, Server, Datenbank.
  ///
  /// Die lokale Zeile fällt zuletzt — solange sie steht, ist der Anhang
  /// wiederfindbar. Ein fehlgeschlagenes Löschen auf dem Server hinterlässt
  /// höchstens eine verwaiste Datei, nie einen Geist in der Liste.
  Future<void> entfernen(VehicleAttachmentData anhang,
      {String? abteilungId}) async {
    final lokal = anhang.localPath;
    if (lokal != null && !kIsWeb) {
      try {
        final datei = File(lokal);
        if (datei.existsSync()) await datei.delete();
      } catch (e) {
        appLog.w('Lokale Kopie ${anhang.id} nicht löschbar', error: e);
      }
    }

    final c = client;
    final objekt = objektImBucket(anhang.storagePath, kVehicleAttachmentsBucket);
    if (c != null && objekt != null) {
      try {
        await c.storage.from(kVehicleAttachmentsBucket).remove([objekt]);
      } catch (e) {
        appLog.w('Anhang ${anhang.id} nicht vom Server löschbar', error: e);
      }
      if (abteilungId != null) {
        try {
          await c
              .from('vehicle_attachments')
              .delete()
              .eq('abteilung_id', abteilungId)
              .eq('id', anhang.id);
        } catch (e) {
          appLog.w('Anhang-Zeile ${anhang.id} nicht löschbar', error: e);
        }
      }
    }

    await db.attachmentDao.deleteAttachment(anhang.id);
  }

  /// Reicht nach, was noch keinen Platz auf dem Server hat. Läuft nach dem
  /// Sync — ein Anhang, der offline entstanden ist, gehört danach dazu.
  Future<int> nachreichen({String? abteilungId}) async {
    if (client == null || kIsWeb) return 0;
    var gereicht = 0;
    for (final a in await db.attachmentDao.getAll()) {
      if (a.storagePath != null) continue;
      final lokal = a.localPath;
      if (lokal == null || !File(lokal).existsSync()) continue;
      try {
        await _hochladen(
          id: a.id,
          bytes: await File(lokal).readAsBytes(),
          typ: a.mimeType,
          abteilungId: abteilungId,
        );
        gereicht++;
      } catch (e) {
        appLog.w('Anhang ${a.id} konnte nicht nachgereicht werden', error: e);
      }
    }
    return gereicht;
  }

  /// Holt die Anhang-Zeilen der Abteilung vom Server in den lokalen Bestand.
  ///
  /// **Zeilenweise statt über den Snapshot** (siehe `kSyncedTables`): Ein
  /// Alt-Client würde beim Veröffentlichen sonst alle Unterlagen löschen.
  ///
  /// ⚠️ [VehicleAttachmentData.localPath] wird dabei **nie** überschrieben.
  /// Der Server weiß nichts davon, welche Datei auf DIESEM Gerät liegt — ein
  /// blindes Upsert würde bei jedem Zug die ganze Offline-Zusage löschen und
  /// wäre erst im Einsatz zu bemerken.
  Future<int> zieheAnhaenge(String abteilungId) async {
    final c = client;
    if (c == null) return 0;
    final zeilen = List<Map<String, dynamic>>.from(await c
        .from('vehicle_attachments')
        .select()
        .eq('abteilung_id', abteilungId));

    final lokalBekannt = {
      for (final a in await db.attachmentDao.getAll()) a.id: a,
    };
    final gezogen = <int>{};
    for (final r in zeilen) {
      final id = (r['id'] as num).toInt();
      gezogen.add(id);
      await db.attachmentDao.upsert(VehicleAttachmentsCompanion(
        id: Value(id),
        vehicleId: Value((r['vehicle_id'] as num).toInt()),
        title: Value(r['title'] as String),
        kind: Value(r['kind'] as String),
        mimeType: Value(r['mime_type'] as String),
        storagePath: Value(r['storage_path'] as String?),
        sizeBytes: Value((r['size_bytes'] as num?)?.toInt() ?? 0),
        // Die Kopie auf diesem Gerät bleibt, was sie war.
        localPath: Value(lokalBekannt[id]?.localPath),
      ));
    }

    // Was der Server nicht mehr kennt, ist gelöscht — aber nur, wenn es
    // dort überhaupt schon einmal ankam. Ein Anhang, der noch auf sein
    // Hochladen wartet, darf hier nicht verschwinden.
    for (final a in lokalBekannt.values) {
      if (gezogen.contains(a.id) || a.storagePath == null) continue;
      await db.attachmentDao.deleteAttachment(a.id);
    }
    return zeilen.length;
  }

  Future<void> _hochladen({
    required int id,
    required Uint8List bytes,
    required String typ,
    String? abteilungId,
  }) async {
    final c = client;
    // Ohne Abteilung gibt es keinen gültigen Objektnamen — der Ordner IST
    // die Abteilung, und der Server lehnt alles andere ab.
    if (c == null || abteilungId == null) return;
    final objekt = '$abteilungId/${id}_${DateTime.now().millisecondsSinceEpoch}'
        '${_endung(typ)}';
    try {
      await c.storage.from(kVehicleAttachmentsBucket).uploadBinary(
            objekt,
            bytes,
            fileOptions: FileOptions(contentType: typ, upsert: true),
          );
      final marker = '$kSupabaseImagePrefix$kVehicleAttachmentsBucket/$objekt';
      await db.attachmentDao.upsert(VehicleAttachmentsCompanion(
        id: Value(id),
        storagePath: Value(marker),
      ));
      final zeile = await db.attachmentDao.getById(id);
      if (zeile != null) {
        await c.from('vehicle_attachments').upsert({
          'abteilung_id': abteilungId,
          'id': zeile.id,
          'vehicle_id': zeile.vehicleId,
          'title': zeile.title,
          'kind': zeile.kind,
          'mime_type': zeile.mimeType,
          'storage_path': marker,
          'size_bytes': zeile.sizeBytes,
        });
      }
    } catch (e) {
      // Kein Rethrow: Der Anhang liegt lokal und in der Datenbank, das
      // Nachreichen holt ihn beim nächsten Mal.
      appLog.w('Anhang $id nicht hochladbar', error: e);
    }
  }

  String _endung(String typ) => switch (typ) {
        'application/pdf' => '.pdf',
        'image/png' => '.png',
        'image/webp' => '.webp',
        _ => '.jpg',
      };

  /// Schreibt unter einem eindeutigen Namen in den App-Ordner. Zeitstempel
  /// wie bei den Bildern: Eine ersetzte Datei darf nie denselben Pfad
  /// bekommen, sonst zeigt ein Betrachter aus dem Zwischenspeicher weiter
  /// die alte.
  Future<String> _schreibeLokal(String dateiname, Uint8List bytes) async {
    final dir = await ordner();
    final ziel = p.join(
      dir.path,
      'anhang_${DateTime.now().microsecondsSinceEpoch}'
          '${p.extension(dateiname)}',
    );
    final datei = await File(ziel).create(recursive: true);
    await datei.writeAsBytes(bytes, flush: true);
    return datei.path;
  }
}
