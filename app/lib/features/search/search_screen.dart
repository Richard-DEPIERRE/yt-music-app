import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/features/search/search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(SearchResult r) async {
    if (r.type != 'song' || r.videoId == null) return;
    final track = Track(
      videoId: r.videoId!,
      title: r.title,
      artistName: r.artistName ?? 'Unknown',
      albumName: r.albumName,
      durationMs: r.durationMs ?? 0,
    );
    await ref.read(audioHandlerProvider).playTrack(track);
    if (mounted) context.go('/now-playing');
  }

  String _subtitleFor(SearchResult r) {
    final parts = <String>[
      r.type,
      if (r.artistName != null) r.artistName!,
      if (r.albumName != null) r.albumName!,
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) =>
              ref.read(searchQueryProvider.notifier).state = v,
          decoration: const InputDecoration(
            hintText: 'Search music',
            border: InputBorder.none,
          ),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final r = items[i];
            return ListTile(
              leading: r.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: r.thumbnail!.url,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : const SizedBox(width: 48, height: 48),
              title: Text(r.title),
              subtitle: Text(_subtitleFor(r)),
              onTap: () => _onTap(r),
            );
          },
        ),
      ),
    );
  }
}
