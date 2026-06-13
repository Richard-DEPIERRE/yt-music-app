import 'package:ytmusic/core/api/models/search_result.dart';

class AlbumTrack {
  AlbumTrack({
    required this.videoId,
    required this.title,
    this.artistName,
    this.durationMs,
    this.trackNumber,
    this.thumbnail,
  });

  factory AlbumTrack.fromJson(Map<String, dynamic> json) => AlbumTrack(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        durationMs: json['durationMs'] as int?,
        trackNumber: json['trackNumber'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final int? durationMs;
  final int? trackNumber;
  final Thumbnail? thumbnail;
}

class AlbumDetail {
  AlbumDetail({
    required this.browseId,
    required this.title,
    required this.items,
    this.artistName,
    this.artistBrowseId,
    this.year,
    this.trackCount,
    this.thumbnail,
    this.audioPlaylistId,
  });

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
        browseId: json['browseId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        artistBrowseId: json['artistBrowseId'] as String?,
        year: json['year'] as int?,
        trackCount: json['trackCount'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
        audioPlaylistId: json['audioPlaylistId'] as String?,
        items: (json['items'] as List)
            .map((e) => AlbumTrack.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String browseId;
  final String title;
  final String? artistName;
  final String? artistBrowseId;
  final int? year;
  final int? trackCount;
  final Thumbnail? thumbnail;
  final String? audioPlaylistId;
  final List<AlbumTrack> items;
}
