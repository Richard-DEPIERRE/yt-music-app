import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'recently_played_dao.g.dart';

@DriftAccessor(tables: [RecentlyPlayed, Tracks])
class RecentlyPlayedDao extends DatabaseAccessor<AppDatabase>
    with _$RecentlyPlayedDaoMixin {
  RecentlyPlayedDao(super.db);

  Future<void> replaceAll(List<RecentlyPlayedCompanion> rows) async {
    await transaction(() async {
      await delete(recentlyPlayed).go();
      if (rows.isNotEmpty) {
        await batch((b) => b.insertAll(recentlyPlayed, rows));
      }
    });
  }

  Stream<List<RecentlyPlayedData>> watchAll() {
    final q = select(recentlyPlayed)
      ..orderBy([
        (r) => OrderingTerm(expression: r.playedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }
}
