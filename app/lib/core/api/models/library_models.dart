import 'package:ytmusic/core/api/models/search_result.dart';

class LikedSong {
  LikedSong({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory LikedSong.fromJson(Map<String, dynamic> j) => LikedSong(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
}

class PagedLikedSongs {
  PagedLikedSongs({required this.items, this.continuation});

  factory PagedLikedSongs.fromJson(Map<String, dynamic> j) => PagedLikedSongs(
        items: (j['items'] as List)
            .map((e) => LikedSong.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<LikedSong> items;
  final String? continuation;
}

class PlaylistSummary {
  PlaylistSummary({
    required this.browseId,
    required this.title,
    required this.isOwn,
    this.description,
    this.trackCount,
    this.thumbnail,
  });

  factory PlaylistSummary.fromJson(Map<String, dynamic> j) => PlaylistSummary(
        browseId: j['browseId'] as String,
        title: j['title'] as String,
        isOwn: j['isOwn'] as bool? ?? true,
        description: j['description'] as String?,
        trackCount: j['trackCount'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String browseId;
  final String title;
  final bool isOwn;
  final String? description;
  final int? trackCount;
  final Thumbnail? thumbnail;
}

class PagedPlaylists {
  PagedPlaylists({required this.items, this.continuation});

  factory PagedPlaylists.fromJson(Map<String, dynamic> j) => PagedPlaylists(
        items: (j['items'] as List)
            .map((e) => PlaylistSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<PlaylistSummary> items;
  final String? continuation;
}

class PlaylistTrackInfo {
  PlaylistTrackInfo({
    required this.videoId,
    required this.title,
    this.setVideoId,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
  });

  factory PlaylistTrackInfo.fromJson(Map<String, dynamic> j) =>
      PlaylistTrackInfo(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        setVideoId: j['setVideoId'] as String?,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String videoId;
  final String title;
  final String? setVideoId;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
}

class PlaylistDetail {
  PlaylistDetail({
    required this.browseId,
    required this.title,
    required this.items,
    this.description,
    this.ownerName,
    this.trackCount,
    this.continuation,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) => PlaylistDetail(
        browseId: j['browseId'] as String,
        title: j['title'] as String,
        items: (j['items'] as List)
            .map((e) => PlaylistTrackInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        description: j['description'] as String?,
        ownerName: j['ownerName'] as String?,
        trackCount: j['trackCount'] as int?,
        continuation: j['continuation'] as String?,
      );

  final String browseId;
  final String title;
  final List<PlaylistTrackInfo> items;
  final String? description;
  final String? ownerName;
  final int? trackCount;
  final String? continuation;
}

class ArtistSubscription {
  ArtistSubscription({
    required this.browseId,
    required this.name,
    this.subscriberCount,
    this.thumbnail,
  });

  factory ArtistSubscription.fromJson(Map<String, dynamic> j) =>
      ArtistSubscription(
        browseId: j['browseId'] as String,
        name: j['name'] as String,
        subscriberCount: j['subscriberCount'] as String?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
      );

  final String browseId;
  final String name;
  final String? subscriberCount;
  final Thumbnail? thumbnail;
}

class PagedSubscriptions {
  PagedSubscriptions({required this.items, this.continuation});

  factory PagedSubscriptions.fromJson(Map<String, dynamic> j) =>
      PagedSubscriptions(
        items: (j['items'] as List)
            .map(
              (e) => ArtistSubscription.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<ArtistSubscription> items;
  final String? continuation;
}

class HistoryItem {
  HistoryItem({
    required this.videoId,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.thumbnail,
    this.playedSection,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        artistName: j['artistName'] as String?,
        albumName: j['albumName'] as String?,
        albumBrowseId: j['albumBrowseId'] as String?,
        durationMs: j['durationMs'] as int?,
        thumbnail: j['thumbnail'] == null
            ? null
            : Thumbnail.fromJson(j['thumbnail'] as Map<String, dynamic>),
        playedSection: j['playedSection'] as String?,
      );

  final String videoId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final Thumbnail? thumbnail;
  final String? playedSection;
}

class PagedHistory {
  PagedHistory({required this.items, this.continuation});

  factory PagedHistory.fromJson(Map<String, dynamic> j) => PagedHistory(
        items: (j['items'] as List)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        continuation: j['continuation'] as String?,
      );

  final List<HistoryItem> items;
  final String? continuation;
}
