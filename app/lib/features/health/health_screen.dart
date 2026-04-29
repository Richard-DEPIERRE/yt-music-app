import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytmusic/features/health/health_controller.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backend Health')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(healthFutureProvider.future),
        child: health.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          data: (h) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Row('Status', h.status),
              _Row('Auth', h.authStatus),
              _Row('Last OK', h.lastOkAt?.toIso8601String() ?? '—'),
              _Row('PoT provider', h.potProviderOk?.toString() ?? '—'),
              _Row('Version', h.version),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
