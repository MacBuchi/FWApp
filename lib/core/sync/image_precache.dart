/// image_precache.dart – Pull-time warming of the image cache (M2).
/// Downloads every remote image referenced by the dataset into the
/// flutter_cache_manager cache CachedNetworkImage reads from, so photos are
/// available offline in the vehicle bay ("Offline-Garantie für den Einsatz").
library;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/image_utils.dart';

class ImagePrecacheState {
  final bool running;
  final int done;
  final int failed;
  final int total;

  const ImagePrecacheState({
    this.running = false,
    this.done = 0,
    this.failed = 0,
    this.total = 0,
  });

  /// True once a run finished (successfully or not) this session.
  bool get hasRun => !running && total > 0;
}

class ImagePrecacheNotifier extends Notifier<ImagePrecacheState> {
  @override
  ImagePrecacheState build() => const ImagePrecacheState();

  /// Fetches all remote dataset images into the local cache. Already cached
  /// files are served from disk by the cache manager, so re-runs after every
  /// pull are cheap. No-op while a run is already in progress.
  Future<void> run() async {
    if (state.running) return;

    final db = ref.read(appDatabaseProvider);
    final paths = <String>{};
    for (final e in await db.equipmentDao.getAll()) {
      if (isRemoteImagePath(e.imagePath)) paths.add(e.imagePath!);
    }
    for (final v in await db.vehicleDao.getAll()) {
      if (isRemoteImagePath(v.imagePath)) paths.add(v.imagePath!);
    }
    if (paths.isEmpty) {
      state = const ImagePrecacheState();
      return;
    }

    state = ImagePrecacheState(running: true, total: paths.length);
    var done = 0;
    var failed = 0;
    for (final path in paths) {
      final url = isSupabaseImagePath(path) ? supabaseImageUrl(path) : path;
      try {
        if (url == null) throw StateError('Kein Server konfiguriert');
        await DefaultCacheManager().getSingleFile(
          url,
          key: path, // must match resolveImage's cacheKey
          headers: supabaseStorageHeaders?.call() ?? const {},
        );
        done++;
      } catch (e) {
        failed++;
        appLog.w('Bild-Precache fehlgeschlagen für $path: $e');
      }
      state = ImagePrecacheState(
          running: true, done: done, failed: failed, total: paths.length);
    }
    state = ImagePrecacheState(
        running: false, done: done, failed: failed, total: paths.length);
    appLog.i('Bild-Precache: $done/${paths.length} geladen, $failed Fehler.');
  }
}

final imagePrecacheProvider =
    NotifierProvider<ImagePrecacheNotifier, ImagePrecacheState>(
        ImagePrecacheNotifier.new);
