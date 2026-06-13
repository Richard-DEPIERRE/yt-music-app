import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';

/// Reactive download status for a single track ('not_downloaded', 'queued',
/// 'downloading', 'downloaded', 'failed').
final AutoDisposeStreamProviderFamily<String, String> downloadStatusProvider =
    StreamProvider.autoDispose.family<String, String>((ref, videoId) {
  final db = ref.watch(appDatabaseProvider);
  return db.tracksDao.watchStatus(videoId);
});

/// Enqueue a set of tracks for download (pinned manual download).
///
/// The optional `ensure` list contains minimal TracksCompanion rows to insert
/// before enqueueing — used when the track may not yet exist in the DB (e.g.
/// radio / autoplay tracks). Existing rows are never overwritten
/// (insertOrIgnore).
final enqueueDownloadsProvider = Provider<
    Future<void> Function(
      List<String>, {
      List<TracksCompanion> ensure,
    })>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(downloadRepositoryProvider);
  final coordinator = ref.watch(downloadCoordinatorProvider);
  return (videoIds, {List<TracksCompanion> ensure = const []}) async {
    if (ensure.isNotEmpty) await db.downloadsDao.ensureTracks(ensure);
    await repo.enqueue(videoIds);
    await coordinator.processQueueOnce();
  };
});
