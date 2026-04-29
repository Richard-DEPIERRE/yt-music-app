import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';
import 'package:ytmusic/core/api/models/search_result.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int statusCode = 200;
  String body = '{"status":"ok","auth_status":"ok","last_ok_at":null,'
      '"pot_provider_ok":null,"version":"0.1.0"}';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

void main() {
  test('injects CF Access headers and base URL', () async {
    final adapter = _RecordingAdapter();
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://ytmusic.example.com',
        cfAccessClientId: 'CID',
        cfAccessClientSecret: 'CSECRET',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final result = await client.getHealth();

    expect(result.status, 'ok');
    expect(result.authStatus, 'ok');
    expect(result.version, '0.1.0');

    expect(
      adapter.lastRequest!.uri.toString(),
      'https://ytmusic.example.com/v1/health',
    );
    expect(adapter.lastRequest!.headers['CF-Access-Client-Id'], 'CID');
    expect(adapter.lastRequest!.headers['CF-Access-Client-Secret'], 'CSECRET');
  });

  test('throws ApiException on non-2xx', () async {
    final adapter = _RecordingAdapter()..statusCode = 401;
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://ytmusic.example.com',
        cfAccessClientId: 'CID',
        cfAccessClientSecret: 'CSECRET',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    expect(client.getHealth(), throwsA(isA<ApiException>()));
  });

  test('search() returns parsed list of results', () async {
    final adapter = _RecordingAdapter()
      ..body = '{"items":[{"type":"song","videoId":"abc","title":"T",'
          '"artistName":"A","durationMs":180000}],"continuation":null}';
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://x',
        cfAccessClientId: 'I',
        cfAccessClientSecret: 'S',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final result = await client.search('hello');
    expect(result, isA<List<SearchResult>>());
    expect(result.length, 1);
    expect(result.first.title, 'T');
    expect(
      adapter.lastRequest!.uri.toString(),
      'https://x/v1/search?q=hello&limit=20',
    );
  });

  test('resolveStream() returns parsed StreamInfo', () async {
    final adapter = _RecordingAdapter()
      ..body = '{"videoId":"abc","url":"https://rr/x",'
          '"expiresAt":"2026-04-30T12:00:00Z","codec":"opus",'
          '"container":"webm","bitrate":160000,'
          '"approxDurationMs":180000,"contentLength":4321}';
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://x',
        cfAccessClientId: 'I',
        cfAccessClientSecret: 'S',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final stream = await client.resolveStream('abc', codec: 'opus');
    expect(stream.url, 'https://rr/x');
    expect(stream.codec, 'opus');
    expect(
      adapter.lastRequest!.uri.toString(),
      'https://x/v1/track/abc/stream?codec=opus&quality=high',
    );
  });
}
