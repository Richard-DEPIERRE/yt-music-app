import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/library/library_repository.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;
  late LibraryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    repo = LibraryRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  test('refreshLiked upserts tracks and marks isLiked=true', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [LikedSong(videoId: 'v1', title: 'T', artistName: 'A')],
      ),
    );
    await repo.refreshLiked();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked.map((t) => t.videoId).toList(), ['v1']);
  });

  test('refreshLiked clears isLiked for tracks no longer liked', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [LikedSong(videoId: 'v1', title: 'T')],
      ),
    );
    await repo.refreshLiked();
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
    await repo.refreshLiked();
    final liked = await db.tracksDao.watchLiked().first;
    expect(liked, isEmpty);
  });

  test('refreshLikedIfStale skips network when fresh', () async {
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
    await repo.refreshLiked();
    clearInteractions(api);
    await repo.refreshLikedIfStale();
    verifyNever(() => api.getLikedSongs(limit: any(named: 'limit')));
  });

  test('refreshPlaylistDetail replaces tracks atomically', () async {
    when(() => api.getPlaylistDetail('PL1')).thenAnswer(
      (_) async => PlaylistDetail(
        browseId: 'PL1',
        title: 'Mix',
        items: [
          PlaylistTrackInfo(videoId: 'v1', setVideoId: 's1', title: 'T1'),
          PlaylistTrackInfo(videoId: 'v2', setVideoId: 's2', title: 'T2'),
        ],
      ),
    );
    await repo.refreshPlaylistDetail('PL1');
    final tracks = await db.playlistsDao.tracksFor('PL1');
    expect(tracks.map((t) => t.setVideoId).toList(), ['s1', 's2']);
  });
}
