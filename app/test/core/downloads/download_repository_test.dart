import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

void main() {
  late AppDatabase db;
  late List<String> deleted;
  late DownloadRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deleted = [];
    repo = DownloadRepository(
      db,
      capBytes: 1000,
      deleteFile: (p) async => deleted.add(p),
    );
  });
  tearDown(() => db.close());

  Future<void> downloaded(String id, int size, {bool pinned = false}) async {
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(videoId: id, title: id),
    );
    await db.downloadsDao.markDownloaded(id,
        localPath: '/audio/$id.m4a', sizeBytes: size, codec: 'aac', bitrate: 1);
    if (pinned) await db.downloadsDao.setPinned([id], pinned: true);
  }

  test('eviction deletes LRU unpinned until under cap', () async {
    await downloaded('a', 600); // unpinned, oldest
    await downloaded('b', 600); // unpinned
    // total unpinned = 1200 > cap 1000 -> evict oldest (a, 600) -> 600 <= 1000
    await repo.runEviction();
    expect(deleted, ['/audio/a.m4a']);
    final a = await db.tracksDao.getById('a');
    expect(a!.downloadStatus, 'not_downloaded');
    expect(a.localPath, isNull);
  });

  test('eviction never touches pinned tracks', () async {
    await downloaded('p', 5000, pinned: true);
    await repo.runEviction();
    expect(deleted, isEmpty);
  });

  test(
    'eviction removes unpinned LRU but keeps pinned even over cap',
    () async {
    // pinned (manual) downloads totalling 1200 > cap 1000
    // — must be untouched.
    await downloaded('m1', 600, pinned: true);
    await downloaded('m2', 600, pinned: true);
    // unpinned (auto) downloads — oldest first by insertion
    // (lastPlayedAt null).
    await downloaded('a1', 600); // unpinned, total unpinned = 600 <= 1000
    await downloaded('a2', 600); // unpinned, total unpinned = 1200 > 1000
    await repo.runEviction();
    // Only the LRU unpinned track is evicted to get unpinned under cap.
    expect(deleted, ['/audio/a1.m4a']);
    expect((await db.tracksDao.getById('m1'))!.downloadStatus, 'downloaded');
    expect((await db.tracksDao.getById('m2'))!.downloadStatus, 'downloaded');
    final a1Status =
        (await db.tracksDao.getById('a1'))!.downloadStatus;
    expect(a1Status, 'not_downloaded');
    expect((await db.tracksDao.getById('a2'))!.downloadStatus, 'downloaded');
  });

  test('removeDownload deletes file and clears row', () async {
    await downloaded('a', 100);
    await repo.removeDownload('a');
    expect(deleted, ['/audio/a.m4a']);
    final a = await db.tracksDao.getById('a');
    expect(a!.downloadStatus, 'not_downloaded');
  });
}
