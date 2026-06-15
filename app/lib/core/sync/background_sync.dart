import 'dart:io';

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
      // Do NOT call gateway.configure() here. configure() installs a
      // MemoryTaskQueue whose add() returns immediately and hands off to the
      // native layer asynchronously (~20 ms per task). Because this isolate
      // tears down immediately after processQueueOnce() returns, most tasks
      // never reach the OS.
      //
      // Without a configured queue, BackgroundDownloaderGateway.enqueue falls
      // back to `await FileDownloader().enqueue(task)`, which is a direct,
      // synchronous-to-the-caller native handoff. FileDownloader.enqueue() does
      // not require start() — it dispatches straight to the OS background
      // transfer system. Because DownloadCoordinator.processQueueOnce() awaits
      // each gateway.enqueue call, every task is fully handed off to the OS
      // before the dispatcher's finally block runs.
      //
      // The foreground gateway (fileDownloaderGatewayProvider) still calls
      // configure() to get the MemoryTaskQueue's concurrency limiting.
      final gateway = BackgroundDownloaderGateway();

      // Construct coordinator before the inner try so it is reachable in the
      // finally block even if service.run() throws before coordinator is used.
      final coordinator = DownloadCoordinator(
        repository: repo,
        gateway: gateway,
        fetchManifest: api.getManifest,
      );

      try {
        final service = LikedAutoSyncService(
          library: LibraryRepository(db: db, api: api),
          db: db,
          enqueue: repo.enqueue,
        );
        await service.run();

        // No stream watcher runs in this isolate, so drive the coordinator
        // once. reconcile() re-queues rows left as 'downloading' from a
        // previous run; processQueueOnce() enqueues them to FileDownloader's
        // native background transfer system (persists across isolate teardown).
        await coordinator.reconcile();
        await coordinator.processQueueOnce();
      } finally {
        // Always dispose to release the gateway's StreamSubscription +
        // StreamController, even if service.run() / reconcile() / processQueueOnce()
        // throws.
        coordinator.dispose();
        gateway.dispose();
      }
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
    if (Platform.isAndroid) {
      // registerPeriodicTask is Android-only. The iOS workmanager plugin
      // (workmanager 0.5.2, SwiftWorkmanagerPlugin) only handles: initialize,
      // registerOneOffTask, cancelAllTasks, cancelTaskByUniqueName — there is
      // no periodic-task case. Calling it on iOS errors and is silently
      // swallowed, but gating it here makes the behaviour honest and avoids
      // spurious channel errors.
      await Workmanager().registerPeriodicTask(
        _kLikedSyncUniqueName,
        kLikedSyncTask,
        frequency: const Duration(hours: 6),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    }
    // iOS: periodic tasks are unsupported by workmanager; background runs are
    // driven by the OS background-fetch path (UIBackgroundModes: fetch in
    // Info.plist, best-effort, OS-throttled). The reliable trigger is the
    // foreground AutoSyncObserver.
  } on Object {
    // Swallow: workmanager channel is unavailable in test environments and
    // on first run before the plugin is initialised. Foreground sync is the
    // reliable path; background is best-effort.
  }
}
