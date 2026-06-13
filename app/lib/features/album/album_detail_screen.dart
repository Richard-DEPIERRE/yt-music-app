import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/catalog/catalog_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({required this.browseId, super.key});

  final String browseId;

  @override
  ConsumerState<AlbumDetailScreen> createState() =>
      _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(catalogRepositoryProvider);
      if (repo == null) return;
      await repo.refreshAlbumIfStale(widget.browseId);
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(catalogRepositoryProvider);
    if (repo == null) return;
    await repo.refreshAlbum(widget.browseId);
  }

  Future<void> _playFrom(List<Track> ordered, int index) async {
    await ref.read(audioHandlerProvider).setQueue(
          [
            for (final t in ordered)
              wire.Track(
                videoId: t.videoId,
                title: t.title,
                artistName: t.artistName ?? 'Unknown',
                albumName: t.albumName,
                durationMs: t.durationMs ?? 0,
              ),
          ],
          startIndex: index,
        );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<AlbumTrack>>(
          stream: db.albumsDao.watchTracksFor(widget.browseId),
          builder: (ctx, snap) {
            final rows = snap.data ?? const <AlbumTrack>[];
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No tracks.')),
              ]);
            }
            return FutureBuilder<List<Track>>(
              future: db.tracksDao
                  .getByIds(rows.map((r) => r.videoId).toList()),
              builder: (ctx, ts) {
                final tracks = ts.data ?? const <Track>[];
                if (tracks.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                // Preserve album_tracks ordering.
                final byId = {for (final t in tracks) t.videoId: t};
                final ordered = [
                  for (final r in rows)
                    if (byId[r.videoId] != null) byId[r.videoId]!,
                ];
                return ListView.builder(
                  itemCount: ordered.length,
                  itemBuilder: (ctx, i) {
                    final t = ordered[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => _playFrom(ordered, i),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
