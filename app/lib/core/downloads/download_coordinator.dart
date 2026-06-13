import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

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
      for (var i = 0; i < queued.length; i += _kBatchSize) {
        final batch = queued.skip(i).take(_kBatchSize).toList();
        final ids = batch.map((t) => t.videoId).toList();
        try {
          final manifest = await _fetch(ids);
          for (final err in manifest.errors) {
            await _repo.markFailed(err.videoId, err.error, _kMaxAttempts);
          }
          for (final item in manifest.items) {
            _resolved[item.videoId] = item;
            await _repo.markDownloading(item.videoId);
            await _gateway.enqueue(_requestFor(item));
          }
        } on Object catch (e, st) {
          // Transient error (e.g. network blip): leave rows as queued for
          // a later retry. A real per-item resolution failure comes back in
          // manifest.errors above, not here.
          debugPrint('[DownloadCoordinator] batch fetch error: $e\n$st');
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
    switch (e.kind) {
      case DownloadEventKind.complete:
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
        await _repo.runEviction();
      case DownloadEventKind.urlExpired:
        await _reResolveAndResume(e.videoId);
      case DownloadEventKind.failed:
        await _repo.markFailed(e.videoId, 'download_failed', _kMaxAttempts);
        _resolved.remove(e.videoId);
      case DownloadEventKind.progress:
        break;
    }
  }

  Future<void> _reResolveAndResume(String videoId) async {
    try {
      final manifest = await _fetch([videoId]);
      final item = manifest.items
          .where((i) => i.videoId == videoId)
          .cast<ManifestItem?>()
          .firstWhere((_) => true, orElse: () => null);
      if (item == null) {
        await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
        return;
      }
      _resolved[videoId] = item;
      await _gateway.resume(_requestFor(item));
    } on Object {
      await _repo.markFailed(videoId, 'reresolve_failed', _kMaxAttempts);
    }
  }

  void dispose() {
    _queueSub?.cancel();
    _eventSub?.cancel();
  }
}
