import 'package:dio/dio.dart';
import 'package:ytmusic/core/api/api_config.dart';
import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/stream_info.dart';
import 'package:ytmusic/core/api/models/track.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
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
        );

  final Dio dio;

  Future<HealthResult> getHealth() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/health');
      if (res.statusCode != 200 || res.data == null) {
        throw ApiException(res.statusCode ?? 0, 'Unexpected response');
      }
      return HealthResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }
}

extension ApiClientCatalog on ApiClient {
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
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }

  Future<Track> getTrack(String videoId) async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/track/$videoId');
      return Track.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
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
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }
}
