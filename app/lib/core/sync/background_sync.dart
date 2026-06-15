import 'package:workmanager/workmanager.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/background_downloader_gateway.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';
import 'package:ytmusic/core/library/library_repository.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';
import 'package:ytmusic/core/sync/liked_auto_sync_service.dart';

const String kLikedSyncTask = 'com.richarddepierre.ytmusic.likedSync';
const String _kLikedSyncUniqueName = 'liked-sync-periodic';

/// Runs in a SEPARATE isolate (no Riverpod). Builds its own dependencies
/// from secure storage and runs the same [LikedAutoSyncService] used in the
/// foreground.
///
/// NOTE: iOS background execution is OS-throttled (BGTaskScheduler /
/// background-fetch). There are no timing guarantees; the foreground path
/// (AutoSyncObserver) is the reliable trigger. This dispatcher is best-effort.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // WidgetsFlutterBinding is ensured by executeTask before invoking this
    // callback. Build all dependencies from scratch — no Riverpod in this
    // isolate.
    final config = await SettingsRepository().read();
    if (config == null) return true; // not configured -> nothing to do

    final db = AppDatabase();
    try {
      final api = ApiClient(config: config);
      final repo = DownloadRepository(db);
      final gateway = BackgroundDownloaderGateway();
      await gateway.configure();

      final service = LikedAutoSyncService(
        library: LibraryRepository(db: db, api: api),
        db: db,
        enqueue: repo.enqueue,
      );
      await service.run();

      // No stream watcher runs in this isolate, so drive the coordinator once.
      // reconcile() re-queues any rows left as 'downloading' from a previous
      // run; processQueueOnce() enqueues them to FileDownloader's native
      // background transfer system (persists across isolate teardown).
      final coordinator = DownloadCoordinator(
        repository: repo,
        gateway: gateway,
        fetchManifest: api.getManifest,
      );
      await coordinator.reconcile();
      await coordinator.processQueueOnce();
      coordinator.dispose();
      gateway.dispose();
    } finally {
      await db.close();
    }
    return true;
  });
}

/// Initialize workmanager and register the periodic liked-sync task.
/// Call once from main() via unawaited — failures are swallowed so they do
/// not crash the app at startup (platform channels are unavailable in test
/// environments and the registration is best-effort).
Future<void> registerLikedAutoSync() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kLikedSyncUniqueName,
      kLikedSyncTask,
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  } on Object {
    // Swallow: workmanager channel is unavailable in test environments and
    // on first run before the plugin is initialised. Foreground sync is the
    // reliable path; background is best-effort.
  }
}
