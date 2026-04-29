class Thumbnail {
  Thumbnail({required this.url, this.width, this.height});

  factory Thumbnail.fromJson(Map<String, dynamic> json) => Thumbnail(
        url: json['url'] as String,
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  final String url;
  final int? width;
  final int? height;
}

class SearchResult {
  SearchResult({
    required this.type,
    required this.title,
    this.videoId,
    this.browseId,
    this.artistName,
    this.albumName,
    this.durationMs,
    this.thumbnail,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        type: json['type'] as String,
        videoId: json['videoId'] as String?,
        browseId: json['browseId'] as String?,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        albumName: json['albumName'] as String?,
        durationMs: json['durationMs'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String type; // song | video | album | artist | playlist
  final String? videoId;
  final String? browseId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationMs;
  final Thumbnail? thumbnail;
}
