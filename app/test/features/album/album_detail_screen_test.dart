import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/catalog/catalog_providers.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/album/album_detail_screen.dart';

void main() {
  testWidgets('renders album tracks from Drift', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(videoId: 'v1', title: 'Walk On Water'),
    );
    await db.albumsDao.replaceTracks('AL1', [
      AlbumTracksCompanion.insert(
        albumBrowseId: 'AL1',
        videoId: 'v1',
        position: 0,
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        catalogRepositoryProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        home: AlbumDetailScreen(browseId: 'AL1'),
      ),
    ));
    // First pump: StreamBuilder emits album_tracks rows.
    // Second pump: FutureBuilder over tracksDao.getByIds resolves.
    await tester.pump();
    await tester.pump();
    expect(find.text('Walk On Water'), findsOneWidget);

    // Unmount widget tree first so the StreamBuilder cancels its Drift
    // query, then drain the cleanup timer Drift posts via Timer.run,
    // then close the db. Without this, flutter_test trips on pending timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
