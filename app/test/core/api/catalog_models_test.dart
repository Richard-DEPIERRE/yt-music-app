import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/album_detail.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';

void main() {
  test('AlbumDetail.fromJson parses items', () {
    final json = {
      'browseId': 'MPREb_x',
      'title': 'Revival',
      'artistName': 'Eminem',
      'artistBrowseId': 'UCedv',
      'year': 2017,
      'trackCount': 1,
      'thumbnail': {'url': 'https://t/a.jpg', 'width': 600, 'height': 600},
      'audioPlaylistId': 'OLAK5uy_abc',
      'items': [
        {
          'videoId': 'v1',
          'title': 'Walk On Water',
          'artistName': 'Eminem',
          'durationMs': 303000,
          'trackNumber': 1,
          'thumbnail': null,
        },
      ],
    };
    final a = AlbumDetail.fromJson(json);
    expect(a.browseId, 'MPREb_x');
    expect(a.artistName, 'Eminem');
    expect(a.year, 2017);
    expect(a.items.single.videoId, 'v1');
    expect(a.items.single.durationMs, 303000);
  });

  test('ArtistDetail.fromJson parses sections', () {
    final json = {
      'browseId': 'UCabc',
      'name': 'Oasis',
      'description': 'desc',
      'subscriberCount': '3.86M',
      'thumbnail': {'url': 'https://t/ar.jpg', 'width': 540, 'height': 540},
      'radioId': 'RDEMabc',
      'topSongs': [
        {
          'videoId': 's1',
          'title': 'Wonderwall',
          'albumName': 'MG',
          'thumbnail': null,
        },
      ],
      'albums': [
        {
          'browseId': 'MPREb_AY',
          'title': 'Familiar',
          'year': 2018,
          'thumbnail': null,
        },
      ],
      'singles': <Map<String, dynamic>>[],
    };
    final ar = ArtistDetail.fromJson(json);
    expect(ar.name, 'Oasis');
    expect(ar.radioId, 'RDEMabc');
    expect(ar.topSongs.single.videoId, 's1');
    expect(ar.albums.single.browseId, 'MPREb_AY');
    expect(ar.singles, isEmpty);
  });
}
