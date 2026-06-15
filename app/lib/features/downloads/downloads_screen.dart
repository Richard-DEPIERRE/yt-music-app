import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_providers.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';

final _downloadedProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloaded();
});

String _fmtBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) {
    return '${(bytes / (1024 * mb)).toStringAsFixed(2)} GB';
  }
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_downloadedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync liked songs',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result =
                  await ref.read(triggerLikedAutoSyncProvider)(force: true);
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text(result == null
                    ? 'Sync unavailable'
                    : 'Synced — ${result.newlyQueued} new queued'),
              ));
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No downloads yet'));
          }
          final total =
              tracks.fold<int>(0, (sum, t) => sum + (t.sizeBytes ?? 0));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${tracks.length} tracks • ${_fmtBytes(total)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text(t.artistName ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove download',
                        onPressed: () async {
                          try {
                            await ref
                                .read(downloadRepositoryProvider)
                                .removeDownload(t.videoId);
                          } on Object catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not remove download'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
