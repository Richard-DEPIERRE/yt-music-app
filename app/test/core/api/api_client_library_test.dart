import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  ResponseBody? response;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    return response!;
  }
}

ApiClient _client(_RecordingAdapter adapter) {
  final c = ApiClient(
    config: ApiConfig(
      baseUrl: 'https://api.local',
      cfAccessClientId: 'id',
      cfAccessClientSecret: 'secret',
    ),
  );
  c.dio.httpClientAdapter = adapter;
  return c;
}

ResponseBody _ok(String body) => ResponseBody.fromString(
      body,
      200,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  test('getLikedSongs hits /v1/library/liked', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[{"videoId":"v1","title":"T"}],'
          '"continuation":null}');
    final c = _client(a);
    final page = await c.getLikedSongs();
    expect(a.lastPath, '/v1/library/liked');
    expect(page.items.first.videoId, 'v1');
    expect(page.continuation, isNull);
  });

  test('getPlaylistDetail forwards continuation token', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"browseId":"PL1","title":"M","items":[],'
          '"continuation":null}');
    final c = _client(a);
    await c.getPlaylistDetail('PL1', continuation: 'tok');
    expect(a.lastPath, '/v1/library/playlists/PL1');
    expect(a.lastQuery!['continuation'], 'tok');
  });

  test('getSubscriptions hits the right path', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[],"continuation":null}');
    final c = _client(a);
    await c.getSubscriptions();
    expect(a.lastPath, '/v1/library/subscriptions');
  });

  test('getPlaylists hits /v1/library/playlists', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[],"continuation":null}');
    final c = _client(a);
    await c.getPlaylists();
    expect(a.lastPath, '/v1/library/playlists');
  });

  test('getHistory parses albumBrowseId and playedSection', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"items":[{"videoId":"v1","title":"T",'
          '"albumBrowseId":"MPRabc","playedSection":"Today"}],'
          '"continuation":null}');
    final c = _client(a);
    final page = await c.getHistory();
    expect(a.lastPath, '/v1/library/history');
    expect(page.items.first.albumBrowseId, 'MPRabc');
    expect(page.items.first.playedSection, 'Today');
  });
}
