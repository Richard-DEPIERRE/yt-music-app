import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/search_result.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final AutoDisposeFutureProvider<List<SearchResult>> searchResultsProvider =
    FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    return [];
  }
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw ApiException(0, 'Client not configured');
  }
  return client.search(query);
});
