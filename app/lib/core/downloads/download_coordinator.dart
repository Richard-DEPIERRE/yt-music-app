import 'dart:async';
import 'dart:io';

import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';
import 'package:ytmusic/core/logging/app_log.dart';

typedef FetchManifest = Future<DownloadManifest> Function(List<String> ids);
typedef FileSizeOf = int? Function(String path);

int? _realFileSize(String path) {
  final f = File(path);
  return f.existsSync() ? f.lengthSync() : null;
}

const int _kBatchSize = 8;
const int _kMaxAttempts = 3;

class DownloadCoordinator {
  DownloadCoordinator({
    required DownloadRepository repository,
    required FileDownloaderGateway gateway,
    required FetchManifest fetchManifest,
    FileSizeOf fileSizeOf = _realFileSize,
  })  : _repo = repository,
        _gateway = gateway,
        _fetch = fetchManifest,
        _fileSizeOf = fileSizeOf;

  final DownloadRepository _repo;
  final FileDownloaderGateway _gateway;
  final FetchManifest _fetch;
  final FileSizeOf _fileSizeOf;

  StreamSubscription<List<dynamic>>? _queueSub;
  StreamSubscription<DownloadEvent>? _eventSub;
  // last resolved manifest item per videoId, for resume on expiry
  final Map<String, ManifestItem> _resolved = {};
  // Consecutive url-expiry re-resolves per videoId, with no download progress
  // in between. Bounds the otherwise-infinite "fresh URL also 403s" loop for
  // undownloadable videos (bot-gated / PoT-required). Reset on progress/complete.
  final Map<String, int> _reResolveAttempts = {};
  bool _busy = false;

  /// Start watching the queue + gateway events. Call once at app startup
  /// after `reconcile()`.
  void start() {
    _eventSub = _gateway.events.listen(_onEvent);
    _queueSub = _repo
        .watchQueued()
        .listen((_) => unawaited(processQueueOnce()));
  }

  /// Convenience method called at app launch: configure gateway, reconcile
  /// orphans, start watching, then do a first pass.
  Future<void> configureGatewayAndStart() async {
    AppLog.i('Downloads', 'coordinator starting (configure + reconcile)');
    await _gateway.configure();
    await reconcile();
    start();
    await processQueueOnce();
  }

  Future<void> reconcile() async {
    final active = await _gateway.activeVideoIds();
    for (final row in await _repo.orphanedDownloading()) {
      if (!active.contains(row.videoId)) {
        await _repo.requeue(row.videoId);
      }
    }
  }

  /// Resolve + enqueue all currently-queued tracks, in batches of 8.
  /// Transient network errors on a batch are caught and logged; those rows
  /// remain `queued` and will be retried on the next call. Only manifest-
  /// level per-item errors (items in `errors[]`) mark tracks as failed.
  Future<void> processQueueOnce() async {
    if (_busy) return;
    _busy = true;
    try {
      final queued = await _repo.watchQueued().first;
      if (queued.isEmpty) {
        AppLog.d('Downloads', 'processQueueOnce: nothing queued');
        return;
      }
      AppLog.i('Downloads',
          'processQueueOnce: ${queued.length} queued, resolving in '
          'batches of $_kBatchSize');
      for (var i = 0; i < queued.length; i += _kBatchSize) {
        final batch = queued.skip(i).take(_kBatchSize).toList();
        final ids = batch.map((t) => t.videoId).toList();
        try {
          final manifest = await _fetch(ids);
          AppLog.d('Downloads',
              'batch resolved: ${manifest.items.length} ok, '
              '${manifest.errors.length} errors');
          for (final err in manifest.errors) {
            AppLog.w('Downloads',
                'manifest error for ${err.videoId}: ${err.error}');
            await _repo.markFailed(err.videoId, err.error, _kMaxAttempts);
          }
          for (final item in manifest.items) {
            _resolved[item.videoId] = item;
            await _repo.markDownloading(item.videoId);
            try {
              // Fresh (re-)queue → clear any prior abandoned re-resolve budget
              // so a manual retry of a previously-given-up track starts over.
              _reResolveAttempts.remove(item.videoId);
              await _gateway.enqueue(_requestFor(item));
              AppLog.d('Downloads', 'enqueued ${item.videoId} to gateway');
            } on Object catch (e, st) {
              // If the gateway rejects the enqueue, revert to queued so the
              // row is not stranded as 'downloading' until next app launch.
              AppLog.e('Downloads',
                  'gateway enqueue failed for ${item.videoId}', e, st);
              await _repo.requeue(item.videoId);
              _resolved.remove(item.videoId);
            }
          }
        } on Object catch (e, st) {
          // Transient error (e.g. network blip): leave rows as queued for
          // a later retry. A real per-item resolution failure comes back in
          // manifest.errors above, not here.
          AppLog.e('Downloads', 'batch fetch error (rows left queued)', e, st);
          continue;
        }
      }
    } finally {
      _busy = false;
    }
  }

  DownloadRequest _requestFor(ManifestItem item) => DownloadRequest(
        videoId: item.videoId,
        url: item.url,
        ext: item.container, // 'm4a' | 'webm'
      );

  Future<void> _onEvent(DownloadEvent e) async {
    // Progress fires many times per second per task — far too chatty to log.
    // Only the terminal/notable transitions are logged (in their cases below).
    switch (e.kind) {
      case DownloadEventKind.complete:
        AppLog.d('Downloads', 'completed ${e.videoId}');
        final item = _resolved[e.videoId];
        final realSize = e.filePath != null ? _fileSizeOf(e.filePath!) : null;
        final size = realSize ?? item?.contentLength ?? 0;
        await _repo.markDownloaded(
          e.videoId,
          localPath: e.filePath ?? '',
          sizeBytes: size,
          codec: item?.codec ?? 'aac',
          bitrate: item?.bitrate ?? 0,
        );
        _resolved.remove(e.videoId);
        _reResolveAttempts.remove(e.videoId);
        await _repo.runEviction();
      case DownloadEventKind.urlExpired:
        AppLog.d('Downloads', 'url expired for ${e.videoId}; re-resolving');
        await _reResolveAndResume(e.videoId);
      case DownloadEventKind.failed:
        AppLog.w('Downloads', 'download failed for ${e.videoId}');
        await _repo.markFailed(e.videoId, 'download_failed', _kMaxAttempts);
        _resolved.remove(e.videoId);
        _reResolveAttempts.remove(e.videoId);
      case DownloadEventKind.progress:
        // Real bytes arrived → the current URL works, so this isn't the
        // immediate-403 loop. Clear the budget so a later legitimate expiry
        // can still be re-resolved.
        _reResolveAttempts.remove(e.videoId);
    }
  }

  Future<void> _reResolveAndResume(String videoId) async {
    final attempts = (_reResolveAttempts[videoId] ?? 0) + 1;
    _reResolveAttempts[videoId] = attempts;
    if (attempts > _kMaxAttempts) {
      // Fresh URLs keep 403'ing with no progress in between — the video is
      // effectively undownloadable (bot-gated / PoT-required). Give up instead
      // of looping forever and hammering /v1/downloads/manifest.
      AppLog.w('Downloads',
          're-resolve gave up for $videoId after $_kMaxAttempts attempts '
          '(URL keeps expiring with no progress)');
      await _repo.markFailed(videoId, 'url_expired_max_retries', _kMaxAttempts);
      _resolved.remove(videoId);
      // Deliberately keep the (now > max) counter so any further stray expiry
      // events are ignored without resuming or re-fetching. It is cleared when
      // the track is explicitly re-queued (see processQueueOnce), so a manual
      // retry starts fresh.
      return;
    }
    try {
      final manifest = await _fetch([videoId]);
      final item = manifest.items
          .where((i) => i.videoId == videoId)
          .cast<ManifestItem?>()
          .firstWhere((_) => true, orElse: () => null);
      if (item == null) {
        await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
        _resolved.remove(videoId);
        _reResolveAttempts.remove(videoId);
        return;
      }
      _resolved[videoId] = item;
      await _gateway.resume(_requestFor(item));
    } on Object {
      await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
      _resolved.remove(videoId);
      _reResolveAttempts.remove(videoId);
    }
  }

  void dispose() {
    _queueSub?.cancel();
    _eventSub?.cancel();
  }
}
