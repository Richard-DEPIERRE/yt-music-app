import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/album_detail.dart' as album_models;
import 'package:ytmusic/core/catalog/catalog_repository.dart';
import 'package:ytmusic/core/db/database.dart' hide AlbumTrack;

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;
  late CatalogRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    repo = CatalogRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  test('refreshAlbum upserts album + tracks + album_tracks ordering', () async {
    when(() => api.getAlbum(any())).thenAnswer(
      (_) async => album_models.AlbumDetail(
        browseId: 'AL1',
        title: 'Revival',
        artistName: 'Eminem',
        artistBrowseId: 'UCedv',
        trackCount: 2,
        items: [
          album_models.AlbumTrack(
            videoId: 'v1',
            title: 'A',
            durationMs: 1000,
            trackNumber: 1,
          ),
          album_models.AlbumTrack(
            videoId: 'v2',
            title: 'B',
            durationMs: 2000,
            trackNumber: 2,
          ),
        ],
      ),
    );

    await repo.refreshAlbum('AL1');

    final album = await db.albumsDao.getById('AL1');
    expect(album!.title, 'Revival');

    final at = await db.albumsDao.watchTracksFor('AL1').first;
    expect(at.map((r) => r.videoId).toList(), ['v1', 'v2']);

    final tracks = await db.tracksDao.getByIds(['v1', 'v2']);
    expect(tracks.length, 2);
  });
}
