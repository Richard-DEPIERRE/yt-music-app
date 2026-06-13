class ManifestItem {
  ManifestItem({
    required this.videoId,
    required this.url,
    required this.expiresAt,
    required this.codec,
    required this.container,
    required this.bitrate,
    this.contentLength,
    this.artworkUrl,
  });

  factory ManifestItem.fromJson(Map<String, dynamic> json) => ManifestItem(
        videoId: json['videoId'] as String,
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        codec: json['codec'] as String,
        container: json['container'] as String,
        bitrate: json['bitrate'] as int,
        contentLength: json['contentLength'] as int?,
        artworkUrl: json['artworkUrl'] as String?,
      );

  final String videoId;
  final String url;
  final DateTime expiresAt;
  final String codec;
  final String container;
  final int bitrate;
  final int? contentLength;
  final String? artworkUrl;
}

class ManifestError {
  ManifestError({required this.videoId, required this.error});

  factory ManifestError.fromJson(Map<String, dynamic> json) => ManifestError(
        videoId: json['videoId'] as String,
        error: json['error'] as String,
      );

  final String videoId;
  final String error;
}

class DownloadManifest {
  DownloadManifest({required this.items, required this.errors});

  factory DownloadManifest.fromJson(Map<String, dynamic> json) =>
      DownloadManifest(
        items: (json['items'] as List)
            .map((e) => ManifestItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        errors: (json['errors'] as List)
            .map((e) => ManifestError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final List<ManifestItem> items;
  final List<ManifestError> errors;
}
