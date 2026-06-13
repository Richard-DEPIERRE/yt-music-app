import 'package:drift/drift.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/db/database.dart';

class CatalogRepository {
  CatalogRepository({required this.db, required this.api});

  final AppDatabase db;
  final ApiClient api;

  static const Duration _staleTtl = Duration(hours: 24);

  Future<void> refreshAlbum(String browseId) async {
    final detail = await api.getAlbum(browseId);
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.albumsDao.upsertAlbum(
        AlbumsCompanion.insert(
          browseId: detail.browseId,
          title: detail.title,
          artistName: Value(detail.artistName),
          artistBrowseId: Value(detail.artistBrowseId),
          year: Value(detail.year),
          artworkUrl: Value(detail.thumbnail?.url),
          trackCount: Value(detail.trackCount ?? detail.items.length),
          lastSyncedAt: Value(now),
        ),
      );
      for (final t in detail.items) {
        await db.tracksDao.upsertTrack(
          TracksCompanion.insert(
            videoId: t.videoId,
            title: t.title,
            artistName: Value(t.artistName ?? detail.artistName),
            albumName: Value(detail.title),
            albumBrowseId: Value(detail.browseId),
            artistBrowseId: Value(detail.artistBrowseId),
            durationMs: Value(t.durationMs),
            artworkUrl: Value(t.thumbnail?.url ?? detail.thumbnail?.url),
          ),
        );
      }
      await db.albumsDao.replaceTracks(browseId, [
        for (var i = 0; i < detail.items.length; i++)
          AlbumTracksCompanion.insert(
            albumBrowseId: browseId,
            videoId: detail.items[i].videoId,
            position: i,
          ),
      ]);
      await db.syncStateDao.mark('album:$browseId', at: now);
    });
  }

  Future<void> refreshAlbumIfStale(String browseId) async {
    if (await db.syncStateDao.isFresh('album:$browseId', ttl: _staleTtl)) {
      return;
    }
    await refreshAlbum(browseId);
  }
}
