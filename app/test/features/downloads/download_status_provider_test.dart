import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytmusic/core/db/database.dart';
import 'package:ytmusic/core/db/db_providers.dart';
import 'package:ytmusic/features/downloads/download_status_provider.dart';

void main() {
  test('downloadStatus emits the track status', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.tracksDao.upsertTrack(
      TracksCompanion.insert(
        videoId: 'a',
        title: 'a',
        downloadStatus: const Value('downloaded'),
      ),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final status =
        await container.read(downloadStatusProvider('a').future);
    expect(status, 'downloaded');
  });
}
