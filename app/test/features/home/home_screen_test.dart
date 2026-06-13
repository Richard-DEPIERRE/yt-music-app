import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/models/home_feed.dart';
import 'package:ytmusic/features/home/home_controller.dart';
import 'package:ytmusic/features/home/home_screen.dart';

void main() {
  testWidgets('renders section title and item title', (tester) async {
    final section = HomeSection(
      title: 'Quick picks',
      items: [
        HomeItem(kind: 'song', title: 'Gravity', videoId: 'v1'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedProvider.overrideWith((ref) async => [section]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // Pump once to let the FutureProvider resolve.
    await tester.pump();

    expect(find.text('Quick picks'), findsOneWidget);
    expect(find.text('Gravity'), findsOneWidget);
  });
}
