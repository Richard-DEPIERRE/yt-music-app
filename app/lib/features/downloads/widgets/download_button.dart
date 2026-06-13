import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/features/downloads/download_status_provider.dart';

/// A download control for one track (single videoId) or a collection
/// (album/playlist — all videoIds). Reflects the status of the *first* id for
/// the icon; tapping enqueues all ids.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({required this.videoIds, super.key});

  final List<String> videoIds;

  Future<void> _enqueue(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(enqueueDownloadsProvider)(videoIds);
    } on Object catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start download')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstId = videoIds.isNotEmpty ? videoIds.first : '';
    final status = ref.watch(downloadStatusProvider(firstId));

    final statusStr = status.valueOrNull ?? 'not_downloaded';

    switch (statusStr) {
      case 'downloaded':
        return const IconButton(
          icon: Icon(Icons.download_done),
          onPressed: null,
          tooltip: 'Downloaded',
        );
      case 'queued':
      case 'downloading':
        return const IconButton(
          icon: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          onPressed: null,
          tooltip: 'Downloading…',
        );
      case 'failed':
        return IconButton(
          icon: const Icon(Icons.error_outline, color: Colors.redAccent),
          tooltip: 'Failed — tap to retry',
          onPressed: () => _enqueue(context, ref),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: 'Download',
          onPressed: () => _enqueue(context, ref),
        );
    }
  }
}
