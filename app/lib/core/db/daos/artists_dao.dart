import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'artists_dao.g.dart';

@DriftAccessor(tables: [Artists])
class ArtistsDao extends DatabaseAccessor<AppDatabase>
    with _$ArtistsDaoMixin {
  ArtistsDao(super.db);

  Future<void> upsertArtist(ArtistsCompanion row) =>
      into(artists).insertOnConflictUpdate(row);

  Future<void> upsertManyArtists(List<ArtistsCompanion> rows) => batch((b) {
        for (final r in rows) {
          b.insert(artists, r, onConflict: DoUpdate((_) => r));
        }
      });

  Stream<List<Artist>> watchSubscribed() {
    final q = select(artists)
      ..where((a) => a.subscribed.equals(true))
      ..orderBy([(a) => OrderingTerm(expression: a.name)]);
    return q.watch();
  }
}
