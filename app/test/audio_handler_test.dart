import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

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
}
