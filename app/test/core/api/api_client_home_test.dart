import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastPath = options.path;
    return ResponseBody.fromString(
      '{"sections":[{"title":"Quick picks","items":['
      '{"kind":"song","title":"Gravity","videoId":"v1",'
      '"artistName":"yetep"}]}]}',
      200,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
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

void main() {
  test('getHome hits /v1/home and parses sections', () async {
    final a = _RecordingAdapter();
    final home = await _client(a).getHome();
    expect(a.lastPath, '/v1/home');
    expect(home.single.title, 'Quick picks');
    expect(home.single.items.single.videoId, 'v1');
  });
}
