import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/app.dart';
import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/audio/audio_handler.dart';
import 'package:ytmusic/core/audio/audio_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Late-bind the container so the handler's apiClientFactory closure can read
  // from the same container the override is installed on. Two-scope nesting
  // breaks Riverpod's scoping invariant (mediaItemStreamProvider depends on
  // audioHandlerProvider; if the override sits in a child scope, dependent
  // providers must declare `dependencies` — easier to use one scope).
  late final ProviderContainer container;
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
  container = ProviderContainer(
    overrides: [audioHandlerProvider.overrideWithValue(handler)],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UichaaMusicApp(),
    ),
  );
}
