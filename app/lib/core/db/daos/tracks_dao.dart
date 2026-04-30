import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'tracks_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class TracksDao extends DatabaseAccessor<AppDatabase> with _$TracksDaoMixin {
  TracksDao(super.db);

  Future<void> upsertTrack(TracksCompanion row) =>
      into(tracks).insertOnConflictUpdate(row);

  Future<void> upsertManyTracks(List<TracksCompanion> rows) async {
    await batch((b) {
      for (final r in rows) {
        b.insert(tracks, r, onConflict: DoUpdate((_) => r));
      }
    });
  }

  Future<Track?> getById(String id) =>
      (select(tracks)..where((t) => t.videoId.equals(id))).getSingleOrNull();

  Future<List<Track>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (select(tracks)
          ..where((t) => t.videoId.isIn(ids)))
        .get();
    final byId = {for (final r in rows) r.videoId: r};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<List<Track>> allTracks() => select(tracks).get();

  Stream<List<Track>> watchLiked() {
    final q = select(tracks)
      ..where((t) => t.isLiked.equals(true))
      ..orderBy([
        (t) => OrderingTerm(expression: t.likedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }
}
