import 'package:dio/dio.dart';
import 'package:ytmusic/core/api/api_config.dart';
import 'package:ytmusic/core/api/models/album_detail.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/api/models/queue_item.dart';
import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';
import 'package:ytmusic/core/logging/app_log.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  /// Builds an [ApiException] from a Dio error, preserving the response body.
  ///
  /// The body is the single most useful field when debugging: the backend
  /// puts the real upstream cause in `detail` (e.g. for a 502 from
  /// `/v1/library/liked`, the actual ytmusicapi exception / expired-auth
  /// reason). Dio's `message` alone only says "status code 502".
  factory ApiException.fromDio(DioException e) => ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
        body: e.response?.data,
      );

  final int statusCode;
  final String message;

  /// The parsed response body, when the server returned one (often a
  /// `{"detail": "..."}` map describing what failed upstream).
  final Object? body;

  @override
  String toString() => body == null
      ? 'ApiException($statusCode): $message'
      : 'ApiException($statusCode): $message — body: $body';
}

/// Logs every request, response and error (with the response body on failure)
/// through [AppLog] under the `API` tag. Added last so it sees the final
/// request that actually goes out.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLog.d('API', '→ ${options.method} ${options.uri}');
    if (AppLog.logNetworkBodies && options.data != null) {
      AppLog.d('API', '  ↳ request body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final ro = response.requestOptions;
    AppLog.d('API', '← ${response.statusCode} ${ro.method} ${ro.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final ro = err.requestOptions;
    AppLog.e(
      'API',
      '✗ ${err.response?.statusCode ?? '-'} ${ro.method} ${ro.path} '
      '(${err.type.name})${err.message != null ? ' ${err.message}' : ''}',
    );
    final body = err.response?.data;
    if (body != null) {
      AppLog.e('API', '  ↳ response body: $body');
    }
    handler.next(err);
  }
}

class HealthResult {
  HealthResult({
    required this.status,
    required this.authStatus,
    required this.lastOkAt,
    required this.potProviderOk,
    required this.version,
  });

  factory HealthResult.fromJson(Map<String, dynamic> json) => HealthResult(
        status: json['status'] as String,
        authStatus: json['auth_status'] as String,
        lastOkAt: json['last_ok_at'] != null
            ? DateTime.parse(json['last_ok_at'] as String)
            : null,
        potProviderOk: json['pot_provider_ok'] as bool?,
        version: json['version'] as String,
      );

  final String status;
  final String authStatus;
  final DateTime? lastOkAt;
  final bool? potProviderOk;
  final String version;
}

class ApiClient {
  ApiClient({required ApiConfig config})
      : dio = Dio(
          BaseOptions(
            baseUrl: config.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'CF-Access-Client-Id': config.cfAccessClientId,
              'CF-Access-Client-Secret': config.cfAccessClientSecret,
            },
          ),
        ) {
    dio.interceptors.add(_LoggingInterceptor());
    AppLog.i('API', 'ApiClient ready (baseUrl=${config.baseUrl})');
  }

  final Dio dio;

  Future<HealthResult> getHealth() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/health');
      if (res.statusCode != 200 || res.data == null) {
        throw ApiException(res.statusCode ?? 0, 'Unexpected response');
      }
      return HealthResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<SearchResult>> search(
    String query, {
    String? type,
    int limit = 20,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/search',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          'limit': limit,
        },
      );
      final items = (res.data!['items'] as List)
          .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Track> getTrack(String videoId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/track/$videoId');
      return Track.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StreamInfo> resolveStream(
    String videoId, {
    String codec = 'any',
    String quality = 'high',
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/track/$videoId/stream',
        queryParameters: {'codec': codec, 'quality': quality},
      );
      return StreamInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedLikedSongs> getLikedSongs({int limit = 200}) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/library/liked',
        queryParameters: {'limit': limit},
      );
      return PagedLikedSongs.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedPlaylists> getPlaylists() async {
    try {
      final res =
          await dio.get<Map<String, dynamic>>('/v1/library/playlists');
      return PagedPlaylists.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PlaylistDetail> getPlaylistDetail(
    String browseId, {
    String? continuation,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/library/playlists/$browseId',
        queryParameters: {
          if (continuation != null) 'continuation': continuation,
        },
      );
      return PlaylistDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedSubscriptions> getSubscriptions() async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/library/subscriptions',
      );
      return PagedSubscriptions.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedHistory> getHistory() async {
    try {
      final res =
          await dio.get<Map<String, dynamic>>('/v1/library/history');
      return PagedHistory.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AlbumDetail> getAlbum(String browseId) async {
    try {
      final res =
          await dio.get<Map<String, dynamic>>('/v1/album/$browseId');
      return AlbumDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ArtistDetail> getArtist(String browseId) async {
    try {
      final res =
          await dio.get<Map<String, dynamic>>('/v1/artist/$browseId');
      return ArtistDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<QueueItem>> getRadio(String seedVideoId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/radio',
        queryParameters: {'seedVideoId': seedVideoId},
      );
      return (res.data!['items'] as List)
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<QueueItem>> getUpNext(
    String videoId, {
    bool radio = false,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/up-next',
        queryParameters: {'videoId': videoId, 'radio': radio},
      );
      return (res.data!['items'] as List)
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<HomeSection>> getHome() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/home');
      return (res.data!['sections'] as List)
          .map((e) => HomeSection.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DownloadManifest> getManifest(
    List<String> videoIds, {
    String codec = 'aac',
    String quality = 'high',
  }) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/downloads/manifest',
        data: {
          'videoIds': videoIds,
          'codec': codec,
          'quality': quality,
        },
      );
      return DownloadManifest.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
