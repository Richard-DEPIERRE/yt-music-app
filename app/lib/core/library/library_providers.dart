import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return LibraryRepository(
    db: ref.watch(appDatabaseProvider),
    api: api,
  );
});
