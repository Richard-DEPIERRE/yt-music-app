import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/download_manifest.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/downloads/download_coordinator.dart';
import 'package:ytmusic/core/downloads/download_gateway.dart';
import 'package:ytmusic/core/downloads/download_repository.dart';

class FakeGateway implements FileDownloaderGateway {
  final _controller = StreamController<DownloadEvent>.broadcast();
  final List<DownloadRequest> enqueued = [];
  final List<DownloadRequest> resumed = [];
  Set<String> active = {};

  @override
  Stream<DownloadEvent> get events => _controller.stream;
  @override
  Future<void> configure({int maxConcurrent = 3}) async {}
  @override
  Future<void> enqueue(DownloadRequest req) async => enqueued.add(req);
  @override
  Future<void> resume(DownloadRequest req) async => resumed.add(req);
  @override
  Future<void> cancel(String videoId) async {}
  @override
  Future<Set<String>> activeVideoIds() async => active;
  @override
  void dispose() => _controller.close();

  void emit(DownloadEvent e) => _controller.add(e);
}

ManifestItem _item(String id) => ManifestItem(
      videoId: id,
      url: 'https://cdn/$id',
      expiresAt: DateTime(2026, 6, 13, 15),
      codec: 'aac',
      container: 'm4a',
      bitrate: 160000,
      contentLength: 100,
    );

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late DownloadRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repo = DownloadRepository(db, deleteFile: (_) async {});
  });
  tearDown(() => db.close());

  Future<void> seedQueued(String id) async {
    await db.tracksDao
        .upsertTrack(TracksCompanion.insert(videoId: id, title: id));
    await db.downloadsDao.enqueue([id], pinned: true);
  }

  DownloadCoordinator make({
    Future<DownloadManifest> Function(List<String>)? fetch,
    FileSizeOf? fileSizeOf,
  }) =>
      DownloadCoordinator(
        repository: repo,
        gateway: gateway,
        fetchManifest: fetch ??
            (ids) async => DownloadManifest(
                  items: ids.map(_item).toList(),
                  errors: [],
                ),
        fileSizeOf: fileSizeOf ?? (_) => null,
      );

  test('queued rows are resolved and enqueued into the gateway', () async {
    await seedQueued('a');
    final coord = make();
    await coord.processQueueOnce();
    expect(gateway.enqueued.map((r) => r.videoId), ['a']);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloading');
  });

  test('manifest per-item error marks the track failed', () async {
    await seedQueued('bad');
    final coord = make(
      fetch: (ids) async => DownloadManifest(
        items: [],
        errors: [ManifestError(videoId: 'bad', error: 'upstream_breakage')],
      ),
    );
    await coord.processQueueOnce();
    final row = await db.tracksDao.getById('bad');
    expect(row!.downloadStatus, 'failed');
  });

  test('complete event marks downloaded', () async {
    await seedQueued('a');
    final coord = make()..start();
    await coord.processQueueOnce();
    gateway.emit(const DownloadEvent(
      videoId: 'a',
      kind: DownloadEventKind.complete,
      filePath: '/audio/a.m4a',
    ));
    await Future<void>.delayed(Duration.zero);
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'downloaded');
    expect(row.localPath, '/audio/a.m4a');
    coord.dispose();
  });

  test('urlExpired event re-resolves and resumes', () async {
    await seedQueued('a');
    final coord = make()..start();
    await coord.processQueueOnce();
    gateway.emit(
      const DownloadEvent(videoId: 'a', kind: DownloadEventKind.urlExpired),
    );
    await Future<void>.delayed(Duration.zero);
    expect(gateway.resumed.map((r) => r.videoId), ['a']);
    coord.dispose();
  });

  test('reconcile requeues orphaned downloading rows', () async {
    await db.tracksDao
        .upsertTrack(TracksCompanion.insert(videoId: 'a', title: 'a'));
    await db.downloadsDao.markDownloading('a');
    gateway.active = {}; // downloader lost the task
    final coord = make();
    await coord.reconcile();
    final row = await db.tracksDao.getById('a');
    expect(row!.downloadStatus, 'queued');
  });

  test('complete event uses real file size over manifest contentLength',
      () async {
    // fileSizeOf always returns 4242, manifest contentLength is 100 (_item)
    await seedQueued('a');
    final coord = make(fileSizeOf: (_) => 4242)..start();
    await coord.processQueueOnce();
    gateway.emit(const DownloadEvent(
      videoId: 'a',
      kind: DownloadEventKind.complete,
      filePath: '/audio/a.m4a',
    ));
    await Future<void>.delayed(Duration.zero);
    final row = await db.tracksDao.getById('a');
    expect(row!.sizeBytes, 4242);
    coord.dispose();
  });
}
