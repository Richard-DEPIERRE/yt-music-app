import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/app.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build a ProviderContainer eagerly so the handler factory can resolve the
  // ApiClient via Riverpod when audio_service spins it up.
  final container = ProviderContainer();
  final handler = await AudioService.init(
    builder: () => AudioPlaybackHandler(
      apiClientFactory: () => container.read(apiClientProvider),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.richarddepierre.ytmusic.audio',
      androidNotificationChannelName: 'UichaaMusic playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [audioHandlerProvider.overrideWithValue(handler)],
        child: const UichaaMusicApp(),
      ),
    ),
  );
}
