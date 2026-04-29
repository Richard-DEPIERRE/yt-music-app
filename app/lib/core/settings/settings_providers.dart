import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/core/api/api_config.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final apiConfigProvider = FutureProvider<ApiConfig?>((ref) async {
  return ref.watch(settingsRepositoryProvider).read();
});
