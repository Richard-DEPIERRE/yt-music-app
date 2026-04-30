import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/routing/app_router.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(mediaItemStreamProvider);
    final state = ref.watch(playbackStateStreamProvider);
    final handler = ref.watch(audioHandlerProvider);

    final item = mediaItem.valueOrNull;
    if (item == null) return const SizedBox.shrink();

    final playing = state.valueOrNull?.playing ?? false;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        // MiniPlayer lives in MaterialApp.router's `builder:` (above the
        // Navigator), so `context.push(...)` can't find a GoRouter inherited
        // widget. Read the router from Riverpod and call .push directly so
        // the destination is added to the back stack (back arrow + iOS
        // swipe-back work). push returns a Future that resolves on pop.
        onTap: () => unawaited(
          ref.read(appRouterProvider).push<void>('/now-playing'),
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (item.artUri != null)
                CachedNetworkImage(
                  imageUrl: item.artUri.toString(),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              else
                const SizedBox(width: 56, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.artist != null)
                      Text(
                        item.artist!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => playing ? handler.pause() : handler.play(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
