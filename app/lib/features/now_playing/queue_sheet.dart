import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueStreamProvider);
    final handler = ref.watch(audioHandlerProvider);
    return queue.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 120,
        child: Center(child: Text('$e')),
      ),
      data: (List<MediaItem> items) => ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final it = items[i];
          return ListTile(
            title: Text(
              it.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: it.artist == null ? null : Text(it.artist!),
            onTap: () => handler.skipToQueueItem(i),
          );
        },
      ),
    );
  }
}
