import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistTracks])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  Future<void> upsertPlaylist(PlaylistsCompanion row) =>
      into(playlists).insertOnConflictUpdate(row);

  Stream<List<Playlist>> watchAll() {
    final q = select(playlists)
      ..orderBy([(p) => OrderingTerm(expression: p.title)]);
    return q.watch();
  }

  Future<Playlist?> getById(String id) =>
      (select(playlists)..where((p) => p.browseId.equals(id)))
          .getSingleOrNull();

  Future<List<PlaylistTrack>> tracksFor(String playlistBrowseId) {
    final q = select(playlistTracks)
      ..where((t) => t.playlistBrowseId.equals(playlistBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.get();
  }

  Stream<List<PlaylistTrack>> watchTracksFor(String playlistBrowseId) {
    final q = select(playlistTracks)
      ..where((t) => t.playlistBrowseId.equals(playlistBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.watch();
  }

  Future<void> replaceTracks(
    String playlistBrowseId,
    List<PlaylistTracksCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(playlistTracks)
            ..where((t) => t.playlistBrowseId.equals(playlistBrowseId)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(playlistTracks, rows));
    });
  }
}
