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

  test('removeDownload deletes file and clears row', () async {
    await downloaded('a', 100);
    await repo.removeDownload('a');
    expect(deleted, ['/audio/a.m4a']);
    final a = await db.tracksDao.getById('a');
    expect(a!.downloadStatus, 'not_downloaded');
  });
}
