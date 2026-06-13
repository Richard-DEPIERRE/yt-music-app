import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'upsertAlbum + replaceTracks then watchTracksFor returns ordered rows',
    () async {
      await db.albumsDao.upsertAlbum(
        AlbumsCompanion.insert(
          browseId: 'AL1',
          title: 'Revival',
          artistName: const Value('Eminem'),
          trackCount: const Value(2),
        ),
      );
      await db.albumsDao.replaceTracks('AL1', [
        AlbumTracksCompanion.insert(
          albumBrowseId: 'AL1',
          videoId: 'v1',
          position: 0,
        ),
        AlbumTracksCompanion.insert(
          albumBrowseId: 'AL1',
          videoId: 'v2',
          position: 1,
        ),
      ]);

      final rows = await db.albumsDao.watchTracksFor('AL1').first;
      expect(rows.map((r) => r.videoId).toList(), ['v1', 'v2']);

      // replaceTracks is atomic + idempotent
      await db.albumsDao.replaceTracks('AL1', [
        AlbumTracksCompanion.insert(
          albumBrowseId: 'AL1',
          videoId: 'v9',
          position: 0,
        ),
      ]);
      final rows2 = await db.albumsDao.watchTracksFor('AL1').first;
      expect(rows2.map((r) => r.videoId).toList(), ['v9']);
    },
  );
}
