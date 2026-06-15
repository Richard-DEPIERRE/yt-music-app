import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';

void main() {
  test('parses items and errors', () {
    final json = {
      'items': [
        {
          'videoId': 'a',
          'url': 'https://cdn/a',
          'expiresAt': '2026-06-13T15:00:00Z',
          'codec': 'aac',
          'container': 'm4a',
          'bitrate': 160000,
          'contentLength': 4321,
          'artworkUrl': 'https://img/a.jpg',
        },
      ],
      'errors': [
        {'videoId': 'b', 'error': 'upstream_breakage'},
      ],
    };

    final manifest = DownloadManifest.fromJson(json);
    expect(manifest.items.single.videoId, 'a');
    expect(manifest.items.single.container, 'm4a');
    expect(manifest.items.single.contentLength, 4321);
    expect(manifest.errors.single.videoId, 'b');
  });

  test('tolerates null contentLength and artwork', () {
    final manifest = DownloadManifest.fromJson({
      'items': [
        {
          'videoId': 'a',
          'url': 'u',
          'expiresAt': '2026-06-13T15:00:00Z',
          'codec': 'aac',
          'container': 'm4a',
          'bitrate': 160000,
        },
      ],
      'errors': <dynamic>[],
    });
    expect(manifest.items.single.contentLength, isNull);
    expect(manifest.items.single.artworkUrl, isNull);
  });
}
