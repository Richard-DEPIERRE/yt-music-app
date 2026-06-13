import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;
  RequestOptions? captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('getManifest posts videoIds and parses response', () async {
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://example.com',
        cfAccessClientId: 'id',
        cfAccessClientSecret: 'secret',
      ),
    );
    final adapter = _StubAdapter(
      '{"items":[{"videoId":"a","url":"u","expiresAt":"2026-06-13T15:00:00Z",'
      '"codec":"aac","container":"m4a","bitrate":160000}],"errors":[]}',
    );
    client.dio.httpClientAdapter = adapter;

    final manifest = await client.getManifest(['a'], codec: 'aac');

    expect(manifest.items.single.videoId, 'a');
    expect(adapter.captured!.path, '/v1/downloads/manifest');
    expect(adapter.captured!.method, 'POST');
    expect((adapter.captured!.data as Map)['videoIds'], ['a']);
    expect((adapter.captured!.data as Map)['codec'], 'aac');
  });
}
