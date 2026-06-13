import 'package:ytmusic/core/api/models/search_result.dart';

class HomeItem {
  HomeItem({
    required this.kind,
    required this.title,
    this.videoId,
    this.browseId,
    this.playlistId,
    this.artistName,
    this.thumbnail,
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) => HomeItem(
        kind: json['kind'] as String,
        title: json['title'] as String,
        videoId: json['videoId'] as String?,
        browseId: json['browseId'] as String?,
        playlistId: json['playlistId'] as String?,
        artistName: json['artistName'] as String?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(
                json['thumbnail'] as Map<String, dynamic>,
              )
            : null,
      );

  final String kind; // song | album | artist | playlist
  final String title;
  final String? videoId;
  final String? browseId;
  final String? playlistId;
  final String? artistName;
  final Thumbnail? thumbnail;
}

class HomeSection {
  HomeSection({required this.title, required this.items});

  factory HomeSection.fromJson(Map<String, dynamic> json) => HomeSection(
        title: json['title'] as String,
        items: (json['items'] as List)
            .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String title;
  final List<HomeItem> items;
}
