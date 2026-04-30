import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/settings/settings_providers.dart';

final apiClientProvider = Provider<ApiClient?>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config == null || !config.isComplete) {
    return null;
  }
  return ApiClient(config: config);
});
