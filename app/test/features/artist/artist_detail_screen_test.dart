import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/artist_detail.dart';
import 'package:ytmusic/features/artist/artist_detail_screen.dart';

void main() {
  testWidgets('renders artist name and top song', (tester) async {
    final artist = ArtistDetail(
      browseId: 'UCabc',
      name: 'Oasis',
      subscriberCount: '3.86M',
      topSongs: [ArtistTopSong(videoId: 's1', title: 'Wonderwall')],
      albums: const [],
      singles: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        artistDetailProvider('UCabc').overrideWith((ref) async => artist),
      ],
      child: const MaterialApp(
        home: ArtistDetailScreen(browseId: 'UCabc'),
      ),
    ));
    await tester.pump();
    expect(find.text('Oasis'), findsOneWidget);
    expect(find.text('Wonderwall'), findsOneWidget);
  });
}
