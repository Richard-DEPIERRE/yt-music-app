import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'package:ytmusic/core/downloads/download_gateway.dart';

const String _kGroup = 'audio';

class BackgroundDownloaderGateway implements FileDownloaderGateway {
  BackgroundDownloaderGateway() {
    _sub = FileDownloader().updates.listen(_onUpdate);
  }

  final _controller = StreamController<DownloadEvent>.broadcast();
  late final StreamSubscription<TaskUpdate> _sub;

  @override
  Stream<DownloadEvent> get events => _controller.stream;

  MemoryTaskQueue? _queue;

  @override
  Future<void> configure({int maxConcurrent = 3}) async {
    final tq = MemoryTaskQueue()..maxConcurrent = maxConcurrent;
    FileDownloader().addTaskQueue(tq);
    _queue = tq;
    await FileDownloader().start();
  }

  DownloadTask _task(DownloadRequest req) => DownloadTask(
        taskId: req.videoId,
        url: req.url,
        filename: '${req.videoId}.${req.ext}',
        directory: 'audio',
        // baseDirectory defaults to applicationDocuments
        group: _kGroup,
        updates: Updates.statusAndProgress,
        allowPause: true,
        // retries defaults to 0; backoff is handled by the coordinator
      );

  @override
  Future<void> enqueue(DownloadRequest req) async {
    final task = _task(req);
    final tq = _queue;
    if (tq != null) {
      tq.add(task);
    } else {
      await FileDownloader().enqueue(task);
    }
  }

  @override
  Future<void> resume(DownloadRequest req) async {
    // background_downloader keeps the .partial file keyed by taskId; a fresh
    // enqueue with the same taskId + new URL resumes via HTTP Range.
    await FileDownloader().enqueue(_task(req));
  }

  @override
  Future<void> cancel(String videoId) async {
    await FileDownloader().cancelTasksWithIds([videoId]);
  }

  @override
  Future<Set<String>> activeVideoIds() async {
    final records = await FileDownloader().database.allRecords();
    return records.map((r) => r.taskId).toSet();
  }

  void _onUpdate(TaskUpdate update) {
    final videoId = update.task.taskId;
    if (update is TaskProgressUpdate) {
      _controller.add(DownloadEvent(
        videoId: videoId,
        kind: DownloadEventKind.progress,
        progress: update.progress,
      ));
      return;
    }
    if (update is TaskStatusUpdate) {
      switch (update.status) {
        case TaskStatus.complete:
          unawaited(_emitComplete(update.task, videoId));
        case TaskStatus.failed:
          final exc = update.exception;
          final expired = exc is TaskHttpException &&
              (exc.httpResponseCode == 403 || exc.httpResponseCode == 410);
          _controller.add(DownloadEvent(
            videoId: videoId,
            kind: expired
                ? DownloadEventKind.urlExpired
                : DownloadEventKind.failed,
          ));
        case TaskStatus.canceled:
        case TaskStatus.paused:
        case TaskStatus.notFound:
        case TaskStatus.waitingToRetry:
        case TaskStatus.enqueued:
        case TaskStatus.running:
          break;
      }
    }
  }

  Future<void> _emitComplete(Task task, String videoId) async {
    final path = await task.filePath();
    _controller.add(DownloadEvent(
      videoId: videoId,
      kind: DownloadEventKind.complete,
      filePath: path,
    ));
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
