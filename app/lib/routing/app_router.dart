import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ytmusic/core/settings/settings_providers.dart';
import 'package:ytmusic/features/health/health_screen.dart';
import 'package:ytmusic/features/library/history_screen.dart';
import 'package:ytmusic/features/library/library_hub_screen.dart';
import 'package:ytmusic/features/library/liked_songs_screen.dart';
import 'package:ytmusic/features/library/playlist_detail_screen.dart';
import 'package:ytmusic/features/library/playlists_screen.dart';
import 'package:ytmusic/features/library/subscriptions_screen.dart';
import 'package:ytmusic/features/now_playing/now_playing_screen.dart';
import 'package:ytmusic/features/onboarding/onboarding_screen.dart';
import 'package:ytmusic/features/search/search_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/search',
    redirect: (context, state) {
      final config = ref.read(apiConfigProvider).valueOrNull;
      final configured = config != null && config.isComplete;
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      if (!configured && !goingToOnboarding) return '/onboarding';
      if (configured && goingToOnboarding) return '/search';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (context, state) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryHubScreen(),
      ),
      GoRoute(
        path: '/library/liked',
        builder: (context, state) => const LikedSongsScreen(),
      ),
      GoRoute(
        path: '/library/playlists',
        builder: (context, state) => const PlaylistsScreen(),
      ),
      GoRoute(
        path: '/library/playlists/:id',
        builder: (context, state) => PlaylistDetailScreen(
          browseId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/library/subscriptions',
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/library/history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
  );
});
