import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;
  late LibraryRepository library;
  late List<({List<String> ids, bool pinned})> enqueued;
  late LikedAutoSyncService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    library = LibraryRepository(db: db, api: api);
    enqueued = [];
    service = LikedAutoSyncService(
      library: library,
      db: db,
      enqueue: (ids, {bool pinned = false}) async =>
          enqueued.add((ids: ids, pinned: pinned)),
    );
  });
  tearDown(() async => db.close());

  void likedReturns(List<String> ids) {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [for (final id in ids) LikedSong(videoId: id, title: id)],
      ),
    );
  }

  test('newly-liked undownloaded track is queued as evictable (pinned=0)',
      () async {
    likedReturns(['v1']);
    final result = await service.run();
    expect(enqueued.length, 1);
    expect(enqueued.single.ids, ['v1']);
    expect(enqueued.single.pinned, false);
    expect(result.newlyQueued, 1);
    expect(result.liked, 1);
  });

  test('already-downloaded newly-liked track is NOT queued', () async {
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'v2',
        title: 'Two',
        downloadStatus: const Value('downloaded'),
        pinned: const Value(true),
      ),
    );
    likedReturns(['v2']);
    final result = await service.run();
    expect(enqueued, isEmpty);
    expect(result.newlyQueued, 0);
  });

  test('evicted-but-still-liked track is NOT re-queued (no thrash)', () async {
    // First sync likes + queues v1.
    likedReturns(['v1']);
    await service.run();
    enqueued.clear();
    // Simulate: v1 was downloaded then evicted -> back to not_downloaded,
    // but it stays liked.
    await db.downloadsDao.clearDownload('v1');
    final v1 = await db.tracksDao.getById('v1');
    expect(v1!.isLiked, true);
    expect(v1.downloadStatus, 'not_downloaded');
    // Second sync: v1 still liked (not newly-liked) -> must NOT be re-queued.
    likedReturns(['v1']);
    final result = await service.run();
    expect(enqueued, isEmpty);
    expect(result.newlyQueued, 0);
  });

  test('unliked tracks have isLiked cleared', () async {
    likedReturns(['v1', 'v2']);
    await service.run();
    likedReturns(['v1']);
    await service.run();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked.map((t) => t.videoId), ['v1']);
  });
}
