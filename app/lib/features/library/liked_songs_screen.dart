import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final AutoDisposeStreamProvider<List<Track>> _likedStreamProvider =
    StreamProvider.autoDispose<List<Track>>((ref) {
  return ref.watch(appDatabaseProvider).tracksDao.watchLiked();
});

class LikedSongsScreen extends ConsumerStatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  ConsumerState<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends ConsumerState<LikedSongsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(libraryRepositoryProvider);
      if (repo == null) return;
      await repo.refreshLikedIfStale();
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    await repo.refreshLiked();
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
    final tracks = ref.watch(_likedStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Liked songs')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: tracks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
            ],
          ),
          data: (rows) => rows.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No liked songs yet.')),
                  ],
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final t = rows[i];
                    return TrackListTile(
                      title: t.title,
                      artist: t.artistName,
                      artworkUrl: t.artworkUrl,
                      onTap: () => _play(t),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
