import 'package:drift/drift.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'albums_dao.g.dart';

@DriftAccessor(tables: [Albums, AlbumTracks])
class AlbumsDao extends DatabaseAccessor<AppDatabase> with _$AlbumsDaoMixin {
  AlbumsDao(super.db);

  Future<void> upsertAlbum(AlbumsCompanion row) =>
      into(albums).insertOnConflictUpdate(row);

  Future<Album?> getById(String browseId) =>
      (select(albums)..where((a) => a.browseId.equals(browseId)))
          .getSingleOrNull();

  Stream<List<AlbumTrack>> watchTracksFor(String albumBrowseId) {
    final q = select(albumTracks)
      ..where((t) => t.albumBrowseId.equals(albumBrowseId))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]);
    return q.watch();
  }

  Future<void> replaceTracks(
    String albumBrowseId,
    List<AlbumTracksCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(albumTracks)
            ..where((t) => t.albumBrowseId.equals(albumBrowseId)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(albumTracks, rows));
    });
  }
}
