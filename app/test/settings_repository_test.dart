import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ytmusic/core/settings/settings_repository.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SettingsRepository repo;

  setUp(() {
    storage = _MockStorage();
    repo = SettingsRepository(storage: storage);
  });

  test('returns null config when nothing stored', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    final config = await repo.read();
    expect(config, isNull);
  });

  test('returns config when all three keys stored', () async {
    when(
      () => storage.read(key: 'api_base_url'),
    ).thenAnswer((_) async => 'https://x.example.com');
    when(
      () => storage.read(key: 'cf_access_client_id'),
    ).thenAnswer((_) async => 'cid');
    when(
      () => storage.read(key: 'cf_access_client_secret'),
    ).thenAnswer((_) async => 'csecret');

    final config = await repo.read();
    expect(config!.baseUrl, 'https://x.example.com');
    expect(config.cfAccessClientId, 'cid');
    expect(config.cfAccessClientSecret, 'csecret');
  });

  test('save writes all three keys', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await repo.save(
      const ApiConfigInput(
        baseUrl: 'https://x.example.com',
        cfAccessClientId: 'cid',
        cfAccessClientSecret: 'csecret',
      ),
    );

    verify(
      () => storage.write(
        key: 'api_base_url',
        value: 'https://x.example.com',
      ),
    ).called(1);
    verify(
      () => storage.write(key: 'cf_access_client_id', value: 'cid'),
    ).called(1);
    verify(
      () => storage.write(key: 'cf_access_client_secret', value: 'csecret'),
    ).called(1);
  });
}
