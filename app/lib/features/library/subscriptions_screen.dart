import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/core/library/library_providers.dart';
import 'package:ytmusic/features/library/widgets/track_list_tile.dart';

final _subsStreamProvider = AutoDisposeStreamProvider<List<Artist>>((ref) {
  return ref.watch(appDatabaseProvider).artistsDao.watchSubscribed();
});

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(libraryRepositoryProvider);
      if (repo == null) return;
      await repo.refreshSubscriptionsIfStale();
    });
  }

  Future<void> _refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    await repo.refreshSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(_subsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: subs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e'),
              ),
            ],
          ),
          data: (rows) => rows.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No subscriptions yet.')),
                  ],
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final a = rows[i];
                    return TrackListTile(
                      title: a.name,
                      artworkUrl: a.artworkUrl,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
