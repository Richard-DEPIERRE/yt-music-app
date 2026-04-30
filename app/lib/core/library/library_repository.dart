import 'package:drift/drift.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/db/database.dart';

class LibraryRepository {
  LibraryRepository({required this.db, required this.api});

  final AppDatabase db;
  final ApiClient api;

  static const Duration _staleTtl = Duration(hours: 1);

  Future<void> refreshLiked() async {
    final page = await api.getLikedSongs();
    final now = DateTime.now().toUtc();
    final newIds = page.items.map((s) => s.videoId).toSet();

    await db.transaction(() async {
      if (newIds.isEmpty) {
        await db.customStatement(
          'UPDATE tracks SET is_liked = 0 WHERE is_liked = 1',
        );
      } else {
        final placeholders = List<String>.filled(newIds.length, '?').join(',');
        await db.customStatement(
          'UPDATE tracks SET is_liked = 0 '
          'WHERE is_liked = 1 AND video_id NOT IN ($placeholders)',
          newIds.toList(),
        );
      }
      for (final s in page.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: s.videoId,
          title: s.title,
          artistName: Value(s.artistName),
          albumName: Value(s.albumName),
          albumBrowseId: Value(s.albumBrowseId),
          durationMs: Value(s.durationMs),
          artworkUrl: Value(s.thumbnail?.url),
          isLiked: const Value(true),
          likedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_liked', at: now);
    });
  }

  Future<void> refreshLikedIfStale() =>
      _ifStale('library_liked', refreshLiked);

  Future<void> refreshPlaylists() async {
    final page = await api.getPlaylists();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      final newIds = page.items.map((p) => p.browseId).toSet();
      if (newIds.isEmpty) {
        await db.customStatement('DELETE FROM playlists');
      } else {
        final placeholders = List<String>.filled(newIds.length, '?').join(',');
        await db.customStatement(
          'DELETE FROM playlists WHERE browse_id NOT IN ($placeholders)',
          newIds.toList(),
        );
      }
      for (final p in page.items) {
        await db.playlistsDao.upsertPlaylist(PlaylistsCompanion.insert(
          browseId: p.browseId,
          title: p.title,
          description: Value(p.description),
          isOwn: Value(p.isOwn),
          trackCount: Value(p.trackCount ?? 0),
          artworkUrl: Value(p.thumbnail?.url),
          lastSyncedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_playlists', at: now);
    });
  }

  Future<void> refreshPlaylistsIfStale() =>
      _ifStale('library_playlists', refreshPlaylists);

  Future<void> refreshPlaylistDetail(String browseId) async {
    final detail = await api.getPlaylistDetail(browseId);
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.playlistsDao.upsertPlaylist(PlaylistsCompanion.insert(
        browseId: detail.browseId,
        title: detail.title,
        description: Value(detail.description),
        ownerName: Value(detail.ownerName),
        trackCount: Value(detail.trackCount ?? detail.items.length),
        lastSyncedAt: Value(now),
      ));
      for (final t in detail.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: t.videoId,
          title: t.title,
          artistName: Value(t.artistName),
          albumName: Value(t.albumName),
          albumBrowseId: Value(t.albumBrowseId),
          durationMs: Value(t.durationMs),
          artworkUrl: Value(t.thumbnail?.url),
        ));
      }
      await db.playlistsDao.replaceTracks(
        browseId,
        [
          for (var i = 0; i < detail.items.length; i++)
            PlaylistTracksCompanion.insert(
              playlistBrowseId: browseId,
              videoId: detail.items[i].videoId,
              setVideoId:
                  detail.items[i].setVideoId ?? detail.items[i].videoId,
              position: i,
            ),
        ],
      );
      await db.syncStateDao.mark('playlist:$browseId', at: now);
    });
  }

  Future<void> refreshPlaylistDetailIfStale(String browseId) =>
      _ifStale('playlist:$browseId', () => refreshPlaylistDetail(browseId));

  Future<void> refreshSubscriptions() async {
    final page = await api.getSubscriptions();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      final newIds = page.items.map((a) => a.browseId).toSet();
      if (newIds.isEmpty) {
        await db.customStatement(
          'UPDATE artists SET subscribed = 0 WHERE subscribed = 1',
        );
      } else {
        final placeholders = List<String>.filled(newIds.length, '?').join(',');
        await db.customStatement(
          'UPDATE artists SET subscribed = 0 '
          'WHERE subscribed = 1 AND browse_id NOT IN ($placeholders)',
          newIds.toList(),
        );
      }
      for (final a in page.items) {
        await db.artistsDao.upsertArtist(ArtistsCompanion.insert(
          browseId: a.browseId,
          name: a.name,
          subscribed: const Value(true),
          artworkUrl: Value(a.thumbnail?.url),
          lastSyncedAt: Value(now),
        ));
      }
      await db.syncStateDao.mark('library_subscriptions', at: now);
    });
  }

  Future<void> refreshSubscriptionsIfStale() =>
      _ifStale('library_subscriptions', refreshSubscriptions);

  Future<void> refreshHistory() async {
    final page = await api.getHistory();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      for (final h in page.items) {
        await db.tracksDao.upsertTrack(TracksCompanion.insert(
          videoId: h.videoId,
          title: h.title,
          artistName: Value(h.artistName),
          albumName: Value(h.albumName),
          albumBrowseId: Value(h.albumBrowseId),
          durationMs: Value(h.durationMs),
          artworkUrl: Value(h.thumbnail?.url),
        ));
      }
      // Spec §5.2: recently_played is server-driven only; we never log
      // plays locally. replaceAll wipes the prior set and rewrites with
      // synthetic descending timestamps so watchAll order matches API order.
      await db.recentlyPlayedDao.replaceAll([
        for (var i = 0; i < page.items.length; i++)
          RecentlyPlayedCompanion.insert(
            videoId: page.items[i].videoId,
            playedAt: now.subtract(Duration(milliseconds: i)),
          ),
      ]);
      await db.syncStateDao.mark('library_history', at: now);
    });
  }

  Future<void> refreshHistoryIfStale() =>
      _ifStale('library_history', refreshHistory);

  Future<void> _ifStale(String key, Future<void> Function() refresh) async {
    if (await db.syncStateDao.isFresh(key, ttl: _staleTtl)) return;
    await refresh();
  }
}
