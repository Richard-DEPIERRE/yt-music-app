import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';

/// Reactive download status for a single track ('not_downloaded', 'queued',
/// 'downloading', 'downloaded', 'failed').
final downloadStatusProvider =
    StreamProvider.family<String, String>((ref, videoId) {
  final db = ref.watch(appDatabaseProvider);
  return db.tracksDao.watchStatus(videoId);
});

/// Enqueue a set of tracks for download (pinned manual download).
final enqueueDownloadsProvider =
    Provider<Future<void> Function(List<String>)>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  final coordinator = ref.watch(downloadCoordinatorProvider);
  return (videoIds) async {
    await repo.enqueue(videoIds, pinned: true);
    await coordinator.processQueueOnce();
  };
});
