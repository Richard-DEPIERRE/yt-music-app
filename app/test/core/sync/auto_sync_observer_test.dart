import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/sync/auto_sync_observer.dart';
import 'package:ytmusic/core/sync/auto_sync_providers.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

void main() {
  testWidgets('triggers a sync on mount and on resume', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          triggerLikedAutoSyncProvider.overrideWithValue(({bool force = false}) async {
            calls++;
            return const LikedSyncResult(liked: 0, newlyQueued: 0);
          }),
        ],
        child: const MaterialApp(
          home: AutoSyncObserver(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump(); // post-frame mount trigger
    expect(calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
  });
}
