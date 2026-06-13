import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/track.dart';

typedef ApiClientFactory = ApiClient? Function();

class AudioPlaybackHandler extends BaseAudioHandler {
  AudioPlaybackHandler({
    required this.apiClientFactory,
    AudioPlayer? player,
    this.localFileFor,
    this.onPlayed,
  }) : _player = player ?? AudioPlayer() {
    _wirePlayerEvents();
  }

  final AudioPlayer _player;
  final ApiClientFactory apiClientFactory;

  /// Optional callback that returns the local file path for a given videoId,
  /// or null if no local file is available.
  final Future<String?> Function(String videoId)? localFileFor;

  /// Optional callback invoked after a track source has been set, with the
  /// videoId of the track that started playing. Used to update lastPlayedAt.
  final void Function(String videoId)? onPlayed;

  /// Chooses the audio source URI for [videoId].
  ///
  /// If [localFileFor] returns a non-null path, returns a `file://` URI for
  /// that path. Otherwise calls [resolveStreamUrl] and returns its result.
  static Future<String> chooseSource({
    required String videoId,
    required Future<String?> Function(String) localFileFor,
    required Future<String> Function(String) resolveStreamUrl,
  }) async {
    final localPath = await localFileFor(videoId);
    if (localPath != null) {
      return Uri.file(localPath).toString();
    }
    return resolveStreamUrl(videoId);
  }
  Track? _currentTrack;

  final List<Track> _queue = [];
  int _index = 0;
  bool _isAdvancing = false;

  String? get currentVideoId => _currentTrack?.videoId;

  void _wirePlayerEvents() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_toState(event));
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_isAdvancing) {
        _isAdvancing = true;
        unawaited(skipToNext().whenComplete(() => _isAdvancing = false));
      }
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
      queueIndex: _index,
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

  MediaItem _toMediaItem(Track track) => MediaItem(
        id: track.videoId,
        title: track.title,
        artist: track.artistName,
        album: track.albumName,
        duration: track.durationMs > 0
            ? Duration(milliseconds: track.durationMs)
            : null,
        artUri: track.thumbnail != null
            ? Uri.parse(track.thumbnail!.url)
            : null,
      );

  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    final api = _requireApi();
    // iOS' AVPlayer cannot natively decode Opus-in-WebM (PlatformException
    // -11828 "Cannot Open"). AAC-in-M4A plays on both iOS and Android. The
    // backend will fall back to whatever's available if AAC isn't served.
    final url = await chooseSource(
      videoId: track.videoId,
      localFileFor: localFileFor ?? (_) async => null,
      resolveStreamUrl: (id) async =>
          (await api.resolveStream(id, codec: 'aac')).url,
    );
    mediaItem.add(_toMediaItem(track));
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    await _player.play();
    onPlayed?.call(track.videoId);
  }

  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
  }) async {
    _queue
      ..clear()
      ..addAll(tracks);
    _index = tracks.isEmpty
        ? 0
        : startIndex.clamp(0, tracks.length - 1);
    queue.add(_queue.map(_toMediaItem).toList());
    if (_queue.isNotEmpty) {
      await playTrack(_queue[_index]);
    }
  }

  Future<void> playTrackWithAutoplay(Track track) async {
    await setQueue([track]);
    try {
      final api = _requireApi();
      final next = await api.getUpNext(track.videoId);
      final followOn = next
          .where((q) => q.videoId != track.videoId)
          .map((q) => q.toTrack())
          .toList();
      if (followOn.isNotEmpty) {
        _queue.addAll(followOn);
        queue.add(_queue.map(_toMediaItem).toList());
      }
    } on Object catch (_) {
      // Autoplay is best-effort; failure just means no follow-on tracks.
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_index + 1 >= _queue.length) return;
    _index += 1;
    await playTrack(_queue[_index]);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_index <= 0) return;
    _index -= 1;
    await playTrack(_queue[_index]);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    await playTrack(_queue[_index]);
  }

  /// Re-resolve the current track's stream URL and resume from the last
  /// known position. Call this when just_audio reports 403/410 from the CDN.
  Future<void> refreshUrl() async {
    final track = _currentTrack;
    if (track == null) return;
    final api = _requireApi();
    // iOS' AVPlayer cannot natively decode Opus-in-WebM (PlatformException
    // -11828 "Cannot Open"). AAC-in-M4A plays on both iOS and Android. The
    // backend will fall back to whatever's available if AAC isn't served.
    final info = await api.resolveStream(track.videoId, codec: 'aac');
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
