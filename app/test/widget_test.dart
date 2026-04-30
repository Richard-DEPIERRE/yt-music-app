import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/app.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

void main() {
  testWidgets('app boots without crashing', (tester) async {
    final player = _MockPlayer();
    when(() => player.playbackEventStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.positionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.bufferedPositionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.durationStream)
        .thenAnswer((_) => const Stream<Duration?>.empty());
    when(() => player.playing).thenReturn(false);
    when(() => player.speed).thenReturn(1);

    final handler = AudioPlaybackHandler(
      player: player,
      apiClientFactory: () => null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioHandlerProvider.overrideWithValue(handler)],
        child: const UichaaMusicApp(),
      ),
    );

    // The router will redirect to /onboarding (no config persisted in tests).
    // Pump a couple of frames so the redirect resolves.
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
