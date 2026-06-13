import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/api/api_providers.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/downloads/background_downloader_gateway.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(appDatabaseProvider));
});

final fileDownloaderGatewayProvider = Provider<FileDownloaderGateway>((ref) {
  final gateway = BackgroundDownloaderGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

final downloadCoordinatorProvider = Provider<DownloadCoordinator>((ref) {
  final coordinator = DownloadCoordinator(
    repository: ref.watch(downloadRepositoryProvider),
    gateway: ref.watch(fileDownloaderGatewayProvider),
    fetchManifest: (ids) {
      final api = ref.read(apiClientProvider);
      // If the user hasn't configured the backend yet, the api is null.
      // Return an empty manifest so queued rows simply wait for the next run.
      if (api == null) {
        return Future.value(DownloadManifest(items: [], errors: []));
      }
      return api.getManifest(ids);
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
