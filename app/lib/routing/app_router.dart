import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ytmusic/core/settings/settings_providers.dart';
import 'package:ytmusic/features/health/health_screen.dart';
import 'package:ytmusic/features/onboarding/onboarding_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/health',
    redirect: (context, state) {
      final config = ref.read(apiConfigProvider).valueOrNull;
      final configured = config != null && config.isComplete;
      final goingToOnboarding = state.matchedLocation == '/onboarding';

      if (!configured && !goingToOnboarding) return '/onboarding';
      if (configured && goingToOnboarding) return '/health';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthScreen(),
      ),
    ],
  );
});
