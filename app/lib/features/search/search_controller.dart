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
  // Only show songs in v1 — album/artist/playlist detail screens are Phase 3.
  // Filtering server-side avoids rendering taps that go nowhere.
  return client.search(query, type: 'song');
});
