import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/downloads/downloads_screen.dart';

void main() {
  testWidgets('lists downloaded tracks', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'a',
        title: 'Song A',
        downloadStatus: const Value('downloaded'),
        sizeBytes: const Value(1000000),
        downloadedAt: Value(DateTime(2026, 6, 13)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Song A'), findsOneWidget);

    // Unmount widget tree first so the StreamBuilder cancels its Drift
    // query, then drain the cleanup timer Drift posts via Timer.run,
    // then close the db. Without this, flutter_test trips on pending timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
