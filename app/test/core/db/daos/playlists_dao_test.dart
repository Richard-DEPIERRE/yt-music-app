import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/playlists_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late PlaylistsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.playlistsDao;
  });
  tearDown(() async => db.close());

  test('watchAll emits playlist summaries', () async {
    await dao.upsertPlaylist(
      PlaylistsCompanion.insert(browseId: 'PL1', title: 'Mix'),
    );
    final first = await dao.watchAll().first;
    expect(first.map((p) => p.browseId).toList(), ['PL1']);
  });

  test('replaceTracks rewrites the entire playlist track list', () async {
    await dao.upsertPlaylist(
      PlaylistsCompanion.insert(browseId: 'PL1', title: 'Mix'),
    );
    await dao.replaceTracks('PL1', [
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v1'),
        setVideoId: Value('s1'),
        position: Value(0),
      ),
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v2'),
        setVideoId: Value('s2'),
        position: Value(1),
      ),
    ]);
    var ids = await dao.tracksFor('PL1');
    expect(ids.map((t) => t.setVideoId).toList(), ['s1', 's2']);

    await dao.replaceTracks('PL1', [
      const PlaylistTracksCompanion(
        playlistBrowseId: Value('PL1'),
        videoId: Value('v3'),
        setVideoId: Value('s3'),
        position: Value(0),
      ),
    ]);
    ids = await dao.tracksFor('PL1');
    expect(ids.map((t) => t.setVideoId).toList(), ['s3']);
  });
}
