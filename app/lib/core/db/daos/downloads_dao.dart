import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'downloads_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  /// Insert minimal rows only if absent; never clobbers existing download
  /// state (uses insertOrIgnore).
  Future<void> ensureTracks(List<TracksCompanion> rows) async {
    await batch((b) {
      for (final r in rows) {
        b.insert(tracks, r, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  Future<void> enqueue(List<String> videoIds, {required bool pinned}) async {
    await (update(tracks)..where((t) => t.videoId.isIn(videoIds))).write(
      TracksCompanion(
        downloadStatus: const Value('queued'),
        pinned: Value(pinned),
        lastDownloadError: const Value(null),
      ),
    );
  }

  Stream<List<Track>> watchQueued() =>
      (select(tracks)..where((t) => t.downloadStatus.equals('queued'))).watch();

  Stream<List<Track>> watchDownloaded() => (select(tracks)
        ..where((t) => t.downloadStatus.equals('downloaded'))
        ..orderBy([
          (t) => OrderingTerm(
              expression: t.downloadedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<Track>> orphanedDownloading() =>
      (select(tracks)..where((t) => t.downloadStatus.equals('downloading')))
          .get();

  Future<void> markDownloading(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(downloadStatus: Value('downloading')),
      );

  Future<void> markDownloaded(
    String videoId, {
    required String localPath,
    required int sizeBytes,
    required String codec,
    required int bitrate,
  }) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        TracksCompanion(
          downloadStatus: const Value('downloaded'),
          localPath: Value(localPath),
          sizeBytes: Value(sizeBytes),
          downloadedCodec: Value(codec),
          downloadedBitrate: Value(bitrate),
          downloadedAt: Value(DateTime.now()),
          lastDownloadError: const Value(null),
        ),
      );

  Future<void> markFailed(String videoId, String error, int attempts) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        TracksCompanion(
          downloadStatus: const Value('failed'),
          lastDownloadError: Value(error),
          downloadAttempts: Value(attempts),
        ),
      );

  Future<void> requeue(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(downloadStatus: Value('queued')),
      );

  Future<void> setPinned(List<String> videoIds, {required bool pinned}) =>
      (update(tracks)..where((t) => t.videoId.isIn(videoIds)))
          .write(TracksCompanion(pinned: Value(pinned)));

  Future<int> unpinnedDownloadedBytes() async {
    final sum = tracks.sizeBytes.sum();
    final q = selectOnly(tracks)
      ..addColumns([sum])
      ..where(tracks.downloadStatus.equals('downloaded') &
          tracks.pinned.equals(false));
    final row = await q.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<List<Track>> lruUnpinned() => (select(tracks)
        ..where((t) =>
            t.downloadStatus.equals('downloaded') & t.pinned.equals(false))
        ..orderBy([
          // Primary: least-recently played first; nulls (never played) come
          // before any played track.
          (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                nulls: NullsOrder.first,
              ),
          // Tie-break: among tracks with the same lastPlayedAt (e.g. all null
          // for auto-downloads that have never been played), evict the oldest
          // download first so the order is deterministic.
          (t) => OrderingTerm(expression: t.downloadedAt),
        ]))
      .get();

  Future<void> clearDownload(String videoId) =>
      (update(tracks)..where((t) => t.videoId.equals(videoId))).write(
        const TracksCompanion(
          downloadStatus: Value('not_downloaded'),
          pinned: Value(false),
          localPath: Value(null),
          sizeBytes: Value(null),
          downloadedCodec: Value(null),
          downloadedBitrate: Value(null),
          downloadedAt: Value(null),
        ),
      );
}
