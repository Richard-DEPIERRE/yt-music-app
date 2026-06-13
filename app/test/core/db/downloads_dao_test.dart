import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(String id, {String status = 'not_downloaded'}) {
    return db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: id,
        title: 'T $id',
        downloadStatus: Value(status),
      ),
    );
  }

  test('enqueue sets queued + pinned for existing tracks', () async {
    await seed('a');
    await db.downloadsDao.enqueue(['a'], pinned: true);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'queued');
    expect(row.pinned, true);
  });

  test('watchQueued emits queued rows', () async {
    await seed('a', status: 'queued');
    final rows = await db.downloadsDao.watchQueued().first;
    expect(rows.map((r) => r.videoId), ['a']);
  });

  test('markDownloaded records file fields', () async {
    await seed('a', status: 'downloading');
    await db.downloadsDao.markDownloaded(
      'a',
      localPath: '/docs/audio/a.m4a',
      sizeBytes: 1000,
      codec: 'aac',
      bitrate: 160000,
    );
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloaded');
    expect(row.localPath, '/docs/audio/a.m4a');
    expect(row.sizeBytes, 1000);
    expect(row.downloadedAt, isNotNull);
  });

  test('unpinnedDownloadedBytes sums only unpinned downloaded', () async {
    await seed('p', status: 'downloading');
    await db.downloadsDao.markDownloaded('p',
        localPath: '/p', sizeBytes: 500, codec: 'aac', bitrate: 1);
    await db.downloadsDao.setPinned(['p'], pinned: true);
    await seed('u', status: 'downloading');
    await db.downloadsDao.markDownloaded('u',
        localPath: '/u', sizeBytes: 700, codec: 'aac', bitrate: 1);
    expect(await db.downloadsDao.unpinnedDownloadedBytes(), 700);
  });

  test('lruUnpinned orders by lastPlayedAt ascending (nulls first)', () async {
    await seed('old', status: 'downloading');
    await db.downloadsDao.markDownloaded('old',
        localPath: '/old', sizeBytes: 1, codec: 'aac', bitrate: 1);
    final rows = await db.downloadsDao.lruUnpinned();
    expect(rows.first.videoId, 'old');
  });
}
