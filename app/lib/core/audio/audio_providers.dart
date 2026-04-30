import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_handler.dart';

final audioHandlerProvider = Provider<AudioPlaybackHandler>((ref) {
  throw UnimplementedError('Override in main() after AudioService.init()');
});

// `dependencies: [audioHandlerProvider]` is required so Riverpod can resolve
// scoping if `audioHandlerProvider` is ever overridden in a child container.
// Without it, reading these providers from a scope that overrides their
// dependency throws an assertion at build time.
final mediaItemStreamProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
  dependencies: [audioHandlerProvider],
);

final playbackStateStreamProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
  dependencies: [audioHandlerProvider],
);
