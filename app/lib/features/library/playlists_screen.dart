import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final AutoDisposeStreamProvider<List<Playlist>> _playlistsStreamProvider =
    StreamProvider.autoDispose<List<Playlist>>((ref) {
  return ref.watch(appDatabaseProvider).playlistsDao.watchAll();
});

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(libraryRepositoryProvider);
      if (repo == null) return;
      await repo.refreshPlaylistsIfStale();
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    await repo.refreshPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final pls = ref.watch(_playlistsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: pls.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e'),
              ),
            ],
          ),
          data: (rows) => rows.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No playlists yet.')),
                  ],
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final p = rows[i];
                    return TrackListTile(
                      title: p.title,
                      artist: p.trackCount > 0
                          ? '${p.trackCount} tracks'
                          : null,
                      artworkUrl: p.artworkUrl,
                      onTap: () => context.go('/library/playlists/${p.browseId}'),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
