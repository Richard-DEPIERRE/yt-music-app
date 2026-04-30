import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_config.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

// Synchronous holder for the current API config. Seeded at app boot in
// main.dart from SettingsRepository.read() before runApp, then mutated
// via `ref.read(apiConfigProvider.notifier).state = newConfig` when the
// user saves credentials in onboarding. Kept synchronous so GoRouter's
// redirect can decide on the first frame without racing the keychain
// read.
final apiConfigProvider = StateProvider<ApiConfig?>((ref) => null);
