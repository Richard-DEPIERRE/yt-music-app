import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/logging/app_log.dart';

final AutoDisposeFutureProvider<HealthResult> healthFutureProvider =
    FutureProvider.autoDispose<HealthResult>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    AppLog.w('Health', 'health check skipped: client not configured');
    throw ApiException(0, 'Client not configured');
  }
  final result = await client.getHealth();
  AppLog.i('Health',
      'status=${result.status} auth=${result.authStatus} '
      'pot=${result.potProviderOk} v=${result.version}');
  return result;
});
