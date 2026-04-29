import 'package:ytmusic/core/api/models/search_result.dart';

class Track {
  Track({
    required this.videoId,
    required this.title,
    required this.artistName,
    required this.durationMs,
    this.albumName,
    this.albumBrowseId,
    this.artistBrowseId,
    this.thumbnail,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String,
        albumName: json['albumName'] as String?,
        albumBrowseId: json['albumBrowseId'] as String?,
        artistBrowseId: json['artistBrowseId'] as String?,
        durationMs: json['durationMs'] as int,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String artistName;
  final String? albumName;
  final String? albumBrowseId;
  final String? artistBrowseId;
  final int durationMs;
  final Thumbnail? thumbnail;
}
