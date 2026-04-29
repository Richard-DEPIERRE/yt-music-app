import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/app.dart';

void main() {
  testWidgets('app boots without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: UichaaMusicApp(),
      ),
    );

    // The router will redirect to /onboarding (no config persisted in tests).
    // Pump a couple of frames so the redirect resolves.
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
