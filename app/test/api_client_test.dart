import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

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
}
