import 'package:ytmusic/core/api/models/search_result.dart';
import 'package:ytmusic/core/api/models/track.dart';

class QueueItem {
  QueueItem({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String?,
        albumName: json['albumName'] as String?,
        albumBrowseId: json['albumBrowseId'] as String?,
        durationMs: json['durationMs'] as int?,
        thumbnail: json['thumbnail'] != null
            ? Thumbnail.fromJson(
                json['thumbnail'] as Map<String, dynamic>,
              )
            : null,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;

  Track toTrack() => Track(
        videoId: videoId,
        title: title,
        artistName: artistName ?? 'Unknown',
        albumName: albumName,
        albumBrowseId: albumBrowseId,
        durationMs: durationMs ?? 0,
        thumbnail: thumbnail,
      );
}
