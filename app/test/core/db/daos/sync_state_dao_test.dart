import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/daos/sync_state_dao.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;
  late SyncStateDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.syncStateDao;
  });
  tearDown(() async => db.close());

  test('lastSyncedAt returns null when never synced', () async {
    expect(await dao.lastSyncedAt('library_liked'), isNull);
  });

  test('mark sets lastSyncedAt and is readable', () async {
    final t = DateTime.utc(2026, 4, 30, 10);
    await dao.mark('library_liked', at: t);
    expect(await dao.lastSyncedAt('library_liked'), t);
  });

  test('isFresh true when within ttl, false when stale', () async {
    final now = DateTime.utc(2026, 4, 30, 10);
    await dao.mark('library_liked', at: now);
    expect(
      await dao.isFresh(
        'library_liked',
        ttl: const Duration(minutes: 5),
        now: now.add(const Duration(minutes: 1)),
      ),
      isTrue,
    );
    expect(
      await dao.isFresh(
        'library_liked',
        ttl: const Duration(minutes: 5),
        now: now.add(const Duration(minutes: 6)),
      ),
      isFalse,
    );
  });
}
