import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late _MockApi api;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _MockApi();
    when(() => api.getLikedSongs(limit: any(named: 'limit')))
        .thenAnswer((_) async => PagedLikedSongs(items: const []));
  });
  tearDown(() async => db.close());

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(api),
      ]);

  test('trigger runs the sync when nothing synced yet', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final result = await c.read(triggerLikedAutoSyncProvider)();
    expect(result, isNotNull);
    verify(() => api.getLikedSongs(limit: any(named: 'limit'))).called(1);
  });

  test('trigger is debounced when library_liked is fresh', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(triggerLikedAutoSyncProvider)(); // marks fresh
    clearInteractions(api);
    final result = await c.read(triggerLikedAutoSyncProvider)(); // within ttl
    expect(result, isNull);
    verifyNever(() => api.getLikedSongs(limit: any(named: 'limit')));
  });

  test('force bypasses the debounce', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(triggerLikedAutoSyncProvider)();
    clearInteractions(api);
    final result = await c.read(triggerLikedAutoSyncProvider)(force: true);
    expect(result, isNotNull);
    verify(() => api.getLikedSongs(limit: any(named: 'limit'))).called(1);
  });

  test('no-op (null) when api is not configured', () async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(null),
    ]);
    addTearDown(c.dispose);
    final result = await c.read(triggerLikedAutoSyncProvider)();
    expect(result, isNull);
  });
}
