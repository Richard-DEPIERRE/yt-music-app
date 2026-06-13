import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/queue_item.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

/// Stubs the [player] with the minimum mocks required to construct an
/// AudioPlaybackHandler and to call playTrack.
void _stubPlayer(_MockPlayer player, _MockApi api) {
  when(() => player.playbackEventStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => player.processingStateStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => player.positionStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => player.bufferedPositionStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => player.durationStream)
      .thenAnswer((_) => const Stream<Duration?>.empty());
  when(() => player.playing).thenReturn(false);
  when(() => player.speed).thenReturn(1);
  when(() => player.setAudioSource(any())).thenAnswer((_) async => null);
  when(() => player.play()).thenAnswer((_) async {});
  when(
    () => api.resolveStream(
      any(),
      codec: any(named: 'codec'),
      quality: any(named: 'quality'),
    ),
  ).thenAnswer(
    (_) async => StreamInfo(
      videoId: 'x',
      url: 'https://rr/x',
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
      codec: 'aac',
      container: 'm4a',
      bitrate: 128000,
      approxDurationMs: 0,
    ),
  );
}

/// Creates a handler where getUpNext returns [upNext].
/// If [upNext] is null the method is not stubbed (will throw if called).
AudioPlaybackHandler makeHandler({
  List<QueueItem>? upNext,
}) {
  final api = _MockApi();
  final player = _MockPlayer();
  _stubPlayer(player, api);
  if (upNext != null) {
    when(
      () => api.getUpNext(
        any(),
        radio: any(named: 'radio'),
      ),
    ).thenAnswer((_) async => upNext);
  }
  return AudioPlaybackHandler(
    player: player,
    apiClientFactory: () => api,
  );
}

void main() {
  late _MockApi api;
  late _MockPlayer player;
  late AudioPlaybackHandler handler;

  setUpAll(() {
    registerFallbackValue(_FakeAudioSource());
  });

  setUp(() {
    api = _MockApi();
    player = _MockPlayer();
    when(() => player.playbackEventStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.processingStateStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.positionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.bufferedPositionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.durationStream)
        .thenAnswer((_) => const Stream<Duration?>.empty());
    when(() => player.playing).thenReturn(false);
    when(() => player.speed).thenReturn(1);
    handler = AudioPlaybackHandler(
      player: player,
      apiClientFactory: () => api,
    );
  });

  test('playTrack resolves stream URL and starts playback', () async {
    final track = Track(
      videoId: 'abc',
      title: 'T',
      artistName: 'A',
      durationMs: 180000,
    );
    when(
      () => api.resolveStream(
        any(),
        codec: any(named: 'codec'),
        quality: any(named: 'quality'),
      ),
    ).thenAnswer(
      (_) async => StreamInfo(
        videoId: 'abc',
        url: 'https://rr/x',
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
        codec: 'opus',
        container: 'webm',
        bitrate: 160000,
        approxDurationMs: 180000,
      ),
    );
    when(() => player.setAudioSource(any())).thenAnswer((_) async => null);
    when(() => player.play()).thenAnswer((_) async {});

    await handler.playTrack(track);

    verify(() => api.resolveStream('abc', codec: 'aac')).called(1);
    verify(() => player.setAudioSource(any())).called(1);
    verify(() => player.play()).called(1);
  });

  test('refreshUrl re-resolves and resumes from position', () async {
    final track = Track(
      videoId: 'abc',
      title: 'T',
      artistName: 'A',
      durationMs: 180000,
    );
    when(
      () => api.resolveStream(
        any(),
        codec: any(named: 'codec'),
        quality: any(named: 'quality'),
      ),
    ).thenAnswer(
      (_) async => StreamInfo(
        videoId: 'abc',
        url: 'https://rr/x2',
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
        codec: 'opus',
        container: 'webm',
        bitrate: 160000,
        approxDurationMs: 180000,
      ),
    );
    when(() => player.position).thenReturn(const Duration(seconds: 42));
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => null);
    when(() => player.play()).thenAnswer((_) async {});

    await handler.playTrack(track);
    // After 403/410 mid-playback, the handler should re-resolve and seek back.
    await handler.refreshUrl();

    verify(
      () => player.setAudioSource(
        any(),
        initialPosition: const Duration(seconds: 42),
      ),
    ).called(1);
  });

  // ── B6: multi-track queue ─────────────────────────────────────────────────

  test('setQueue then skipToNext advances current track', () async {
    final h = makeHandler();
    await h.setQueue([
      Track(videoId: 'a', title: 'A', artistName: 'x', durationMs: 0),
      Track(videoId: 'b', title: 'B', artistName: 'x', durationMs: 0),
    ]);
    expect(h.currentVideoId, 'a');

    await h.skipToNext();
    expect(h.currentVideoId, 'b');
  });

  test('skipToPrevious at index 0 stays at 0', () async {
    final h = makeHandler();
    await h.setQueue([
      Track(videoId: 'a', title: 'A', artistName: 'x', durationMs: 0),
    ]);
    await h.skipToPrevious();
    expect(h.currentVideoId, 'a');
  });

  // ── B7: radio autoplay ────────────────────────────────────────────────────

  test('playTrackWithAutoplay loads up-next into the queue', () async {
    final h = makeHandler(upNext: [
      QueueItem(videoId: 'n1', title: 'N1', artistName: 'x'),
      QueueItem(videoId: 'n2', title: 'N2', artistName: 'x'),
    ]);
    await h.playTrackWithAutoplay(
      Track(
        videoId: 'seed',
        title: 'Seed',
        artistName: 'x',
        durationMs: 0,
      ),
    );
    expect(h.currentVideoId, 'seed');
    // queue = [seed, n1, n2]
    await h.skipToNext();
    expect(h.currentVideoId, 'n1');
  });
}
