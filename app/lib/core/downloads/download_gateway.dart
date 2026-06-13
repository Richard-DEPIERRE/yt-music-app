/// What the coordinator asks the gateway to fetch.
class DownloadRequest {
  const DownloadRequest({
    required this.videoId,
    required this.url,
    required this.ext, // 'm4a' | 'webm'
  });

  final String videoId;
  final String url;
  final String ext;
}

enum DownloadEventKind { progress, complete, failed, urlExpired }

/// A normalized event emitted by the gateway for one videoId.
class DownloadEvent {
  const DownloadEvent({
    required this.videoId,
    required this.kind,
    this.progress = 0,
    this.filePath,
  });

  final String videoId;
  final DownloadEventKind kind;
  final double progress; // 0..1, only for progress events
  final String? filePath; // absolute path, only for complete events
}

/// Abstraction over background_downloader so the coordinator is testable
/// with a fake.
abstract class FileDownloaderGateway {
  Future<void> configure({int maxConcurrent = 3});

  /// Begin (or resume) a download. Uses videoId as the task id.
  Future<void> enqueue(DownloadRequest req);

  /// Re-point an in-flight/partial download at a fresh URL and resume.
  Future<void> resume(DownloadRequest req);

  Future<void> cancel(String videoId);

  /// videoIds the downloader still has live/persisted tasks for
  /// (used for launch reconciliation).
  Future<Set<String>> activeVideoIds();

  Stream<DownloadEvent> get events;

  /// Release resources (close the events stream, cancel subscriptions).
  void dispose();
}
