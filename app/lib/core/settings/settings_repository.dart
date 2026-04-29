import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ytmusic/core/api/api_config.dart';

class ApiConfigInput {
  const ApiConfigInput({
    required this.baseUrl,
    required this.cfAccessClientId,
    required this.cfAccessClientSecret,
  });

  final String baseUrl;
  final String cfAccessClientId;
  final String cfAccessClientSecret;
}

class SettingsRepository {
  SettingsRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kBaseUrl = 'api_base_url';
  static const _kClientId = 'cf_access_client_id';
  static const _kClientSecret = 'cf_access_client_secret';

  final FlutterSecureStorage _storage;

  Future<ApiConfig?> read() async {
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final clientId = await _storage.read(key: _kClientId);
    final clientSecret = await _storage.read(key: _kClientSecret);

    if (baseUrl == null || clientId == null || clientSecret == null) {
      return null;
    }

    return ApiConfig(
      baseUrl: baseUrl,
      cfAccessClientId: clientId,
      cfAccessClientSecret: clientSecret,
    );
  }

  Future<void> save(ApiConfigInput input) async {
    await _storage.write(key: _kBaseUrl, value: input.baseUrl);
    await _storage.write(key: _kClientId, value: input.cfAccessClientId);
    await _storage.write(
      key: _kClientSecret,
      value: input.cfAccessClientSecret,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kClientId);
    await _storage.delete(key: _kClientSecret);
  }
}
