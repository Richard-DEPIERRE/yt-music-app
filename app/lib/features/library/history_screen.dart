import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(libraryRepositoryProvider);
      if (repo == null) return;
      await repo.refreshHistoryIfStale();
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    await repo.refreshHistory();
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
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<RecentlyPlayedData>>(
          stream: db.recentlyPlayedDao.watchAll(),
          builder: (ctx, snap) {
            final rows = snap.data ?? const <RecentlyPlayedData>[];
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No history yet.')),
                ],
              );
            }
            return FutureBuilder<List<Track>>(
              future: db.tracksDao
                  .getByIds(rows.map((r) => r.videoId).toList()),
              builder: (ctx, ts) {
                final tracks = ts.data ?? const <Track>[];
                if (tracks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
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
