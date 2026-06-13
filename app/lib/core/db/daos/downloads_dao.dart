import 'package:drift/drift.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/tables.dart';

part 'downloads_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

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
          (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                nulls: NullsOrder.first,
              ),
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
