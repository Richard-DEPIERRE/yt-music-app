import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(mediaItemStreamProvider);
    final state = ref.watch(playbackStateStreamProvider);
    final handler = ref.watch(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: mediaItem.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Nothing playing'));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (item.artUri != null)
                  CachedNetworkImage(
                    imageUrl: item.artUri.toString(),
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 24),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (item.artist != null) Text(item.artist!),
                const Spacer(),
                _Transport(state: state, handler: handler),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.handler});

  final AsyncValue<PlaybackState> state;
  final AudioPlaybackHandler handler;

  @override
  Widget build(BuildContext context) {
    final playing = state.valueOrNull?.playing ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          iconSize: 64,
          onPressed: () => playing ? handler.pause() : handler.play(),
        ),
      ],
    );
  }
}
