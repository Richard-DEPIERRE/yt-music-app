import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';

void main() {
  group('AudioPlaybackHandler.chooseSource', () {
    test('returns file:// URI when local path exists', () async {
      final result = await AudioPlaybackHandler.chooseSource(
        videoId: 'abc',
        localFileFor: (_) async => '/data/music/abc.m4a',
        resolveStreamUrl: (_) async => 'https://cdn/abc',
      );
      expect(result, 'file:///data/music/abc.m4a');
    });

    test('falls back to stream URL when no local path', () async {
      final result = await AudioPlaybackHandler.chooseSource(
        videoId: 'abc',
        localFileFor: (_) async => null,
        resolveStreamUrl: (_) async => 'https://cdn/abc',
      );
      expect(result, 'https://cdn/abc');
    });
  });
}
