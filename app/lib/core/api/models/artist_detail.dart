import 'package:ytmusic/core/api/models/search_result.dart';

class ArtistTopSong {
  ArtistTopSong({
    required this.videoId,
    required this.title,
    this.albumName,
    this.thumbnail,
  });

  factory ArtistTopSong.fromJson(Map<String, dynamic> json) => ArtistTopSong(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        albumName: json['albumName'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String videoId;
  final String title;
  final String? albumName;
  final Thumbnail? thumbnail;
}

class ArtistAlbum {
  ArtistAlbum({
    required this.browseId,
    required this.title,
    this.year,
    this.thumbnail,
  });

  factory ArtistAlbum.fromJson(Map<String, dynamic> json) => ArtistAlbum(
        browseId: json['browseId'] as String,
        title: json['title'] as String,
        year: json['year'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
      );

  final String browseId;
  final String title;
  final int? year;
  final Thumbnail? thumbnail;
}

class ArtistDetail {
  ArtistDetail({
    required this.browseId,
    required this.name,
    required this.topSongs,
    required this.albums,
    required this.singles,
    this.description,
    this.subscriberCount,
    this.thumbnail,
    this.radioId,
  });

  factory ArtistDetail.fromJson(Map<String, dynamic> json) => ArtistDetail(
        browseId: json['browseId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        subscriberCount: json['subscriberCount'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>)
            : null,
        radioId: json['radioId'] as String?,
        topSongs: (json['topSongs'] as List)
            .map((e) => ArtistTopSong.fromJson(e as Map<String, dynamic>))
            .toList(),
        albums: (json['albums'] as List)
            .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
            .toList(),
        singles: (json['singles'] as List)
            .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String browseId;
  final String name;
  final String? description;
  final String? subscriberCount;
  final Thumbnail? thumbnail;
  final String? radioId;
  final List<ArtistTopSong> topSongs;
  final List<ArtistAlbum> albums;
  final List<ArtistAlbum> singles;
}
