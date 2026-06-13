import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/catalog/catalog_repository.dart';
import 'package:ytmusic/core/db/db_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return CatalogRepository(db: ref.watch(appDatabaseProvider), api: api);
});
