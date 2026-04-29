import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';

final AutoDisposeFutureProvider<HealthResult> healthFutureProvider =
    FutureProvider.autoDispose<HealthResult>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw ApiException(0, 'Client not configured');
  }
  return client.getHealth();
});
