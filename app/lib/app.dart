import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/theme/app_theme.dart';
import 'package:ytmusic/features/now_playing/mini_player.dart';
import 'package:ytmusic/routing/app_router.dart';

class UichaaMusicApp extends ConsumerWidget {
  const UichaaMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UichaaMusic',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            const MiniPlayer(),
          ],
        );
      },
    );
  }
}
