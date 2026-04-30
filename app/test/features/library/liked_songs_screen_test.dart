import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/library_models.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/library/liked_songs_screen.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  testWidgets('renders liked tracks streamed from Drift', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = _MockApi();
    when(() => api.getLikedSongs(limit: any(named: 'limit'))).thenAnswer(
      (_) async => PagedLikedSongs(
        items: [
          LikedSong(videoId: 'v1', title: 'Hello', artistName: 'World'),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: LikedSongsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);

    // Unmount the widget tree first so the autoDispose stream provider
    // cancels its Drift query, then drain the cleanup timer Drift posts
    // via Timer.run, then close the db. Without this drain, flutter_test's
    // _verifyInvariants trips on the pending Drift cleanup timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
