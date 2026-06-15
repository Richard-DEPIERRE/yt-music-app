import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

/// Minimum spacing between automatic (non-forced) liked syncs.
const Duration kAutoSyncMinInterval = Duration(minutes: 30);

/// Null when the backend isn't configured yet.
final likedAutoSyncProvider = Provider<LikedAutoSyncService?>((ref) {
  final library = ref.watch(libraryRepositoryProvider);
  if (library == null) return null;
  final repo = ref.watch(downloadRepositoryProvider);
  return LikedAutoSyncService(
    library: library,
    db: ref.watch(appDatabaseProvider),
    enqueue: repo.enqueue,
  );
});

/// Returns a callback that runs the liked auto-sync, debounced to
/// [kAutoSyncMinInterval] unless `force` is true. Returns the result, or null
/// if skipped (debounced) or the backend isn't configured.
final triggerLikedAutoSyncProvider =
    Provider<Future<LikedSyncResult?> Function({bool force})>((ref) {
  return ({bool force = false}) async {
    final service = ref.read(likedAutoSyncProvider);
    if (service == null) return null;
    if (!force) {
      final fresh = await ref
          .read(appDatabaseProvider)
          .syncStateDao
          .isFresh('library_liked', ttl: kAutoSyncMinInterval);
      if (fresh) return null;
    }
    try {
      return await service.run();
    } on Object catch (e) {
      // Auto-sync is best-effort: a failed liked pull (backend 502, offline,
      // expired YT auth, etc.) must never crash the app or surface as an
      // unhandled exception. Log and skip; the next trigger retries.
      debugPrint('Liked auto-sync failed: $e');
      return null;
    }
  };
});
