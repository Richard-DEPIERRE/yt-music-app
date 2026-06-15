import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';
import 'package:ytmusic/features/downloads/downloads_screen.dart';

void main() {
  testWidgets(
      'Sync liked action runs sync and shows a SnackBar',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    var forced = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          triggerLikedAutoSyncProvider.overrideWithValue(
            ({bool force = false}) async {
              forced = force;
              return const LikedSyncResult(liked: 3, newlyQueued: 2);
            },
          ),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pump(); // let the SnackBar appear
    expect(forced, true);
    expect(find.textContaining('2'), findsWidgets);

    // Unmount widget tree so the Drift stream cancels its query,
    // then drain the cleanup timer before db.close().
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
