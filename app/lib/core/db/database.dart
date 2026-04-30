import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/connection.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Tracks,
    Albums,
    AlbumTracks,
    Artists,
    Playlists,
    PlaylistTracks,
    RecentlyPlayed,
    SyncState,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX tracks_download_status ON tracks(download_status)',
          );
          await customStatement(
            'CREATE INDEX tracks_is_liked ON tracks(is_liked) '
            'WHERE is_liked = 1',
          );
          await customStatement(
            'CREATE INDEX tracks_last_played ON tracks(last_played_at)',
          );
          await customStatement(
            'CREATE INDEX tracks_album ON tracks(album_browse_id)',
          );
          await customStatement(
            'CREATE INDEX album_tracks_position '
            'ON album_tracks(album_browse_id, position)',
          );
          await customStatement(
            'CREATE INDEX playlist_tracks_position '
            'ON playlist_tracks(playlist_browse_id, position)',
          );
        },
      );
}
