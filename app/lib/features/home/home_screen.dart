import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/features/home/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _onTap(BuildContext context, WidgetRef ref, HomeItem it) async {
    switch (it.kind) {
      case 'song':
        if (it.videoId == null) return;
        await ref.read(audioHandlerProvider).playTrackWithAutoplay(
              Track(
                videoId: it.videoId!,
                title: it.title,
                artistName: it.artistName ?? 'Unknown',
                durationMs: 0,
                thumbnail: it.thumbnail,
              ),
            );
        if (context.mounted) unawaited(context.push<void>('/now-playing'));
      case 'album':
        if (it.browseId != null) {
          unawaited(context.push<void>('/albums/${it.browseId}'));
        }
      case 'artist':
        if (it.browseId != null) {
          unawaited(context.push<void>('/artists/${it.browseId}'));
        }
      case 'playlist':
        if (it.playlistId != null) {
          unawaited(context.push<void>('/library/playlists/${it.playlistId}'));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            onPressed: () => context.push('/library'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sections) => RefreshIndicator(
          onRefresh: () async => ref.refresh(homeFeedProvider.future),
          child: ListView.builder(
            itemCount: sections.length,
            itemBuilder: (ctx, i) {
              final s = sections[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: s.items.length,
                      itemBuilder: (ctx, j) {
                        final it = s.items[j];
                        return GestureDetector(
                          onTap: () => _onTap(context, ref, it),
                          child: SizedBox(
                            width: 130,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 122,
                                    height: 122,
                                    child: it.thumbnail == null
                                        ? const ColoredBox(
                                            color: Colors.black26,
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: it.thumbnail!.url,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    it.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
