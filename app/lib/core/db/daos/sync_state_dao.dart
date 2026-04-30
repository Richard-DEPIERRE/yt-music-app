import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<DateTime?> lastSyncedAt(String key) async {
    final row = await (select(syncState)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.lastSyncedAt.toUtc();
  }

  Future<void> mark(String key, {required DateTime at, String? etag}) {
    return into(syncState).insertOnConflictUpdate(
      SyncStateData(key: key, lastSyncedAt: at, etag: etag),
    );
  }

  Future<bool> isFresh(
    String key, {
    required Duration ttl,
    DateTime? now,
  }) async {
    final last = await lastSyncedAt(key);
    if (last == null) return false;
    final t = now ?? DateTime.now().toUtc();
    return t.difference(last) < ttl;
  }
}
