import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;
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
  test('getAlbum hits /v1/album/{browseId}', () async {
    final a = _RecordingAdapter()
      ..response = _ok('{"browseId":"MPREb_x","title":"Revival","items":[]}');
    final album = await _client(a).getAlbum('MPREb_x');
    expect(a.lastPath, '/v1/album/MPREb_x');
    expect(album.title, 'Revival');
  });

  test('getArtist hits /v1/artist/{browseId}', () async {
    final a = _RecordingAdapter()
      ..response = _ok(
        '{"browseId":"UCabc","name":"Oasis",'
        '"topSongs":[],"albums":[],"singles":[]}',
      );
    final artist = await _client(a).getArtist('UCabc');
    expect(a.lastPath, '/v1/artist/UCabc');
    expect(artist.name, 'Oasis');
  });
}
