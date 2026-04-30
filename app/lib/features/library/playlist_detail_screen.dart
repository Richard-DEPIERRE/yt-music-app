import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.browseId, super.key});

  final String browseId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends ConsumerState<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(libraryRepositoryProvider);
      if (repo == null) return;
      await repo.refreshPlaylistDetailIfStale(widget.browseId);
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    await repo.refreshPlaylistDetail(widget.browseId);
  }

  Future<void> _play(Track t) async {
    await ref.read(audioHandlerProvider).playTrack(
          wire.Track(
            videoId: t.videoId,
            title: t.title,
            artistName: t.artistName ?? 'Unknown',
            albumName: t.albumName,
            durationMs: t.durationMs ?? 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<PlaylistTrack>>(
          stream: db.playlistsDao.watchTracksFor(widget.browseId),
          builder: (ctx, snap) {
            final rows = snap.data ?? const <PlaylistTrack>[];
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No tracks.')),
                ],
              );
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
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (ctx, i) {
                    final t = tracks[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => _play(t),
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
