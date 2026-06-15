import 'dart:io';

import 'package:ytmusic/core/db/daos/downloads_dao.dart';
import 'package:ytmusic/core/db/database.dart';

const int kDefaultCapBytes = 10 * 1024 * 1024 * 1024; // 10 GB

typedef DeleteFile = Future<void> Function(String path);

Future<void> _realDelete(String path) async {
  final f = File(path);
  if (f.existsSync()) await f.delete();
}

class DownloadRepository {
  DownloadRepository(
    this._db, {
    int capBytes = kDefaultCapBytes,
    DeleteFile deleteFile = _realDelete,
  })  : _capBytes = capBytes,
        _deleteFile = deleteFile;

  final AppDatabase _db;
  final int _capBytes;
  final DeleteFile _deleteFile;

  DownloadsDao get _dao => _db.downloadsDao;

  Future<void> enqueue(List<String> videoIds, {bool pinned = true}) =>
      _dao.enqueue(videoIds, pinned: pinned);

  Stream<List<Track>> watchQueued() => _dao.watchQueued();
  Stream<List<Track>> watchDownloaded() => _dao.watchDownloaded();
  Future<List<Track>> orphanedDownloading() => _dao.orphanedDownloading();

  Future<void> markDownloading(String videoId) => _dao.markDownloading(videoId);

  Future<void> markDownloaded(
    String videoId, {
    required String localPath,
    required int sizeBytes,
    required String codec,
    required int bitrate,
  }) =>
      _dao.markDownloaded(videoId,
          localPath: localPath,
          sizeBytes: sizeBytes,
          codec: codec,
          bitrate: bitrate);

  Future<void> markFailed(String videoId, String error, int attempts) =>
      _dao.markFailed(videoId, error, attempts);

  Future<void> requeue(String videoId) => _dao.requeue(videoId);

  Future<void> removeDownload(String videoId) async {
    final row = await _db.tracksDao.getById(videoId);
    if (row?.localPath != null) await _deleteFile(row!.localPath!);
    await _dao.clearDownload(videoId);
  }

  /// LRU-evict unpinned downloaded tracks until total size <= cap.
  ///
  /// Note: all Phase-5 manual downloads are pinned (`pinned = true`), so this
  /// method is intentionally a no-op in Phase 5. Eviction will become active
  /// in Phase 6 when auto-sync introduces un-pinned (evictable) tracks.
  Future<void> runEviction() async {
    var total = await _dao.unpinnedDownloadedBytes();
    if (total <= _capBytes) return;
    final lru = await _dao.lruUnpinned();
    for (final track in lru) {
      if (total <= _capBytes) break;
      if (track.localPath != null) await _deleteFile(track.localPath!);
      await _dao.clearDownload(track.videoId);
      total -= track.sizeBytes ?? 0;
    }
  }
}
