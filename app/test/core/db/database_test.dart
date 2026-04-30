import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schema creates all expected tables', () async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND "
          "name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
        )
        .get();
    final tableNames = names.map((r) => r.read<String>('name')).toSet();
    expect(
      tableNames,
      containsAll(<String>{
        'tracks',
        'albums',
        'album_tracks',
        'artists',
        'playlists',
        'playlist_tracks',
        'recently_played',
        'sync_state',
        'settings',
      }),
    );
  });

  test('expected indexes exist', () async {
    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final idx = names.map((r) => r.read<String>('name')).toSet();
    expect(
      idx,
      containsAll(<String>{
        'tracks_download_status',
        'tracks_is_liked',
        'tracks_last_played',
        'tracks_album',
        'album_tracks_position',
        'playlist_tracks_position',
      }),
    );
  });
}
