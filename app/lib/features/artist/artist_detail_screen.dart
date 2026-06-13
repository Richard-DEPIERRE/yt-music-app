import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/core/api/models/track.dart' as wire;
import 'package:ytmusic/core/audio/audio_providers.dart';

final AutoDisposeFutureProviderFamily<ArtistDetail, String>
    artistDetailProvider = FutureProvider.autoDispose
        .family<ArtistDetail, String>((ref, browseId) {
  final api = ref.watch(apiClientProvider);
  if (api == null) {
    throw StateError('Client not configured');
  }
  return api.getArtist(browseId);
});

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({required this.browseId, super.key});

  final String browseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistDetailProvider(browseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (a) => ListView(
          children: [
            ListTile(
              title: Text(
                a.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: a.subscriberCount == null
                  ? null
                  : Text('${a.subscriberCount} subscribers'),
            ),
            if (a.topSongs.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Top songs'),
              ),
            for (final s in a.topSongs)
              ListTile(
                title: Text(s.title),
                subtitle:
                    s.albumName == null ? null : Text(s.albumName!),
                onTap: () =>
                    ref.read(audioHandlerProvider).playTrackWithAutoplay(
                          wire.Track(
                            videoId: s.videoId,
                            title: s.title,
                            artistName: a.name,
                            durationMs: 0,
                          ),
                        ),
              ),
            if (a.albums.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Albums'),
              ),
            for (final al in a.albums)
              ListTile(
                title: Text(al.title),
                subtitle:
                    al.year == null ? null : Text('${al.year}'),
                onTap: () => context.push('/albums/${al.browseId}'),
              ),
            if (a.singles.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Singles'),
              ),
            for (final s in a.singles)
              ListTile(
                title: Text(s.title),
                subtitle: s.year == null ? null : Text('${s.year}'),
                onTap: () =>
                    context.push('/albums/${s.browseId}'),
              ),
          ],
        ),
      ),
    );
  }
}
