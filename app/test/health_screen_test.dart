import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/features/health/health_controller.dart';
import 'package:ytmusic/features/health/health_screen.dart';

void main() {
  testWidgets('renders health values from the future provider',
      (tester) async {
    final fakeResult = HealthResult(
      status: 'ok',
      authStatus: 'ok',
      lastOkAt: DateTime.utc(2026, 4, 29, 12),
      potProviderOk: null,
      version: '0.1.0',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthFutureProvider.overrideWith((_) async => fakeResult),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('ok'), findsAtLeastNWidgets(1));
    expect(find.text('0.1.0'), findsOneWidget);
  });

  testWidgets('renders error message when call fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthFutureProvider.overrideWith(
            (_) async => throw ApiException(401, 'unauthorized'),
          ),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('401'), findsOneWidget);
  });
}
