import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/audio/audio_handler.dart';

final audioHandlerProvider = Provider<AudioPlaybackHandler>((ref) {
  throw UnimplementedError('Override in main() after AudioService.init()');
});

final mediaItemStreamProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});
