class StreamInfo {
  StreamInfo({
    required this.videoId,
    required this.url,
    required this.expiresAt,
    required this.codec,
    required this.container,
    required this.bitrate,
    required this.approxDurationMs,
    this.contentLength,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) => StreamInfo(
        videoId: json['videoId'] as String,
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        codec: json['codec'] as String,
        container: json['container'] as String,
        bitrate: json['bitrate'] as int,
        approxDurationMs: json['approxDurationMs'] as int,
        contentLength: json['contentLength'] as int?,
      );

  final String videoId;
  final String url;
  final DateTime expiresAt;
  final String codec;
  final String container;
  final int bitrate;
  final int approxDurationMs;
  final int? contentLength;
}
