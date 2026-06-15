import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';

typedef EnqueueDownloads = Future<void> Function(
  List<String> videoIds, {
  bool pinned,
});

class LikedSyncResult {
  const LikedSyncResult({required this.liked, required this.newlyQueued});

  /// Total liked tracks after the sync.
  final int liked;

  /// Newly-liked, not-yet-downloaded tracks queued for download this run.
  final int newlyQueued;
}

/// Headless (UI-free) liked-songs auto-sync. Runs identically in the foreground
/// and inside the workmanager background isolate.
class LikedAutoSyncService {
  LikedAutoSyncService({
    required LibraryRepository library,
    required AppDatabase db,
    required EnqueueDownloads enqueue,
  })  : _library = library,
        _db = db,
        _enqueue = enqueue;

  final LibraryRepository _library;
  final AppDatabase _db;
  final EnqueueDownloads _enqueue;

  Future<LikedSyncResult> run() async {
    final newlyLiked = await _library.refreshLikedReturningNew();

    final toQueue = <String>[];
    for (final id in newlyLiked) {
      final row = await _db.tracksDao.getById(id);
      if (row != null && row.downloadStatus == 'not_downloaded') {
        toQueue.add(id);
      }
    }
    if (toQueue.isNotEmpty) {
      await _enqueue(toQueue, pinned: false);
    }

    final likedCount = (await _db.tracksDao.getLiked()).length;
    return LikedSyncResult(liked: likedCount, newlyQueued: toQueue.length);
  }
}
