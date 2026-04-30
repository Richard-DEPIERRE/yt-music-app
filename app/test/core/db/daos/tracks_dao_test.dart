import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/tracks_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late TracksDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.tracksDao;
  });
  tearDown(() async => db.close());

  TracksCompanion sample(String id, {bool liked = false}) =>
      TracksCompanion.insert(
        videoId: id,
        title: 'Title $id',
        artistName: const Value('Artist'),
        durationMs: const Value(180000),
        isLiked: Value(liked),
      );

  test('upsertTrack inserts new and updates existing', () async {
    await dao.upsertTrack(sample('v1'));
    await dao.upsertTrack(sample('v1', liked: true));
    final row = await dao.getById('v1');
    expect(row, isNotNull);
    expect(row!.isLiked, isTrue);
  });

  test('watchLiked returns only liked tracks', () async {
    await dao.upsertTrack(sample('v1', liked: true));
    await dao.upsertTrack(sample('v2'));
    await dao.upsertTrack(sample('v3', liked: true));
    final first = await dao.watchLiked().first;
    expect(first.map((t) => t.videoId).toSet(), {'v1', 'v3'});
  });

  test('upsertManyTracks is batched and idempotent', () async {
    await dao.upsertManyTracks([sample('v1'), sample('v2')]);
    await dao.upsertManyTracks([sample('v2'), sample('v3')]);
    final all = await dao.allTracks();
    expect(all.map((t) => t.videoId).toSet(), {'v1', 'v2', 'v3'});
  });

  test('getByIds returns rows in same order as input ids', () async {
    await dao.upsertManyTracks([sample('a'), sample('b'), sample('c')]);
    final ordered = await dao.getByIds(['c', 'a', 'b']);
    expect(ordered.map((t) => t.videoId).toList(), ['c', 'a', 'b']);
  });
}
