import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/features/downloads/download_status_provider.dart';
import 'package:ytmusic/features/downloads/widgets/download_button.dart';

void main() {
  testWidgets('shows download icon when not downloaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadStatusProvider('a')
              .overrideWith((ref) => Stream.value('not_downloaded')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadButton(videoIds: ['a'])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('shows check when downloaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadStatusProvider('a')
              .overrideWith((ref) => Stream.value('downloaded')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadButton(videoIds: ['a'])),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });
}
