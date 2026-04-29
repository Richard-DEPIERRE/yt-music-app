import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/track.dart';

typedef ApiClientFactory = ApiClient? Function();

class AudioPlaybackHandler extends BaseAudioHandler {
  AudioPlaybackHandler({
    required this.apiClientFactory,
    AudioPlayer? player,
  }) : _player = player ?? AudioPlayer() {
    _wirePlayerEvents();
  }

  final AudioPlayer _player;
  final ApiClientFactory apiClientFactory;
  Track? _currentTrack;

  void _wirePlayerEvents() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_toState(event));
    });
  }

  PlaybackState _toState(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _processingState(event.processingState),
      playing: _player.playing,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    );
  }

  AudioProcessingState _processingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  ApiClient _requireApi() {
    final api = apiClientFactory();
    if (api == null) {
      throw StateError('ApiClient not configured');
    }
    return api;
  }

  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    final api = _requireApi();
    final info = await api.resolveStream(track.videoId, codec: 'opus');
    final item = MediaItem(
      id: track.videoId,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      duration: Duration(milliseconds: track.durationMs),
      artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!.url) : null,
    );
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(info.url)));
    await _player.play();
  }

  /// Re-resolve the current track's stream URL and resume from the last
  /// known position. Call this when just_audio reports 403/410 from the CDN.
  Future<void> refreshUrl() async {
    final track = _currentTrack;
    if (track == null) return;
    final api = _requireApi();
    final info = await api.resolveStream(track.videoId, codec: 'opus');
    final position = _player.position;
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(info.url)),
      initialPosition: position,
    );
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}
