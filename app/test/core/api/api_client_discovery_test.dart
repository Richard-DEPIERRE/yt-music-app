import 'dart:convert';

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
    lastQuery = Map<String, dynamic>.from(
      options.queryParameters,
    );
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
  test('getRadio hits /v1/radio with seedVideoId query param', () async {
    final a = _RecordingAdapter()
      ..response = _ok(
        jsonEncode({'items': <dynamic>[], 'continuation': null}),
      );
    await _client(a).getRadio('v0');
    expect(a.lastPath, '/v1/radio');
    expect(a.lastQuery!['seedVideoId'], 'v0');
  });

  test('getUpNext hits /v1/up-next with videoId and parses items', () async {
    final a = _RecordingAdapter()
      ..response = _ok(
        jsonEncode({
          'items': [
            {'videoId': 'v1', 'title': 'Song', 'artistName': 'A'},
          ],
          'continuation': null,
        }),
      );
    final q = await _client(a).getUpNext('v0');
    expect(a.lastPath, '/v1/up-next');
    expect(a.lastQuery!['videoId'], 'v0');
    expect(q.single.videoId, 'v1');
  });

  test('getUpNext passes radio=true when requested', () async {
    final a = _RecordingAdapter()
      ..response = _ok(
        jsonEncode({'items': <dynamic>[], 'continuation': null}),
      );
    await _client(a).getUpNext('v0', radio: true);
    expect(a.lastQuery!['radio'], true);
  });
}
