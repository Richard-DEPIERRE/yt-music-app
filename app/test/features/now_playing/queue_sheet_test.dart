import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';
import 'package:ytmusic/features/now_playing/queue_sheet.dart';

class _MockHandler extends Mock implements AudioPlaybackHandler {}

void main() {
  testWidgets('renders all queue item titles', (tester) async {
    const item1 = MediaItem(id: 'a', title: 'A', artist: 'Artist A');
    const item2 = MediaItem(id: 'b', title: 'B', artist: 'Artist B');
    final handler = _MockHandler();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          queueStreamProvider.overrideWith(
            (ref) => Stream.value([item1, item2]),
          ),
          audioHandlerProvider.overrideWithValue(handler),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QueueSheet()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('calls skipToQueueItem when a tile is tapped',
      (tester) async {
    const item1 = MediaItem(id: 'a', title: 'A');
    const item2 = MediaItem(id: 'b', title: 'B');
    final handler = _MockHandler();
    when(() => handler.skipToQueueItem(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          queueStreamProvider.overrideWith(
            (ref) => Stream.value([item1, item2]),
          ),
          audioHandlerProvider.overrideWithValue(handler),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QueueSheet()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    verify(() => handler.skipToQueueItem(1)).called(1);
  });
}
