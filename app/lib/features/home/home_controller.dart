import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';

final AutoDisposeFutureProvider<List<HomeSection>> homeFeedProvider =
    FutureProvider.autoDispose<List<HomeSection>>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) {
    throw StateError('Client not configured');
  }
  return api.getHome();
});
