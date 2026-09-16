@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/archive_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_active_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_archived_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/unarchive_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/di/archive_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_active_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_archived_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:axiom/src/features/merchants/di/unarchive_merchant_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('merchant archival use-case providers', () {
    test('resolves archival use cases with the default repository', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );
      final lifecycleService = container.read(databaseLifecycleServiceProvider);
      addTearDown(() async {
        await lifecycleService.close();
        container.dispose();
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      // Then
      expect((await lifecycleService.open()).isSuccess, isTrue);
      expect(container.read(archiveMerchantUseCaseProvider), isA<ArchiveMerchantUseCase>());
      expect(container.read(unarchiveMerchantUseCaseProvider), isA<UnarchiveMerchantUseCase>());
      expect(container.read(getActiveMerchantsUseCaseProvider), isA<GetActiveMerchantsUseCase>());
      expect(container.read(getArchivedMerchantsUseCaseProvider), isA<GetArchivedMerchantsUseCase>());
    });

    test('forwards overridden dependencies', () async {
      // Given
      final repository = MockMerchantRepository();
      final merchant = merchantFixture(id: 'merchant');
      when(() => repository.archive(merchant.id, timestamp)).thenAnswer(
        (_) async => Success(merchant),
      );
      when(() => repository.unarchive(merchant.id, timestamp)).thenAnswer(
        (_) async => Success(merchant),
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([merchant]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([merchant]),
      );
      final container = ProviderContainer(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);

      // When
      await container.read(archiveMerchantUseCaseProvider)(merchant.id);
      await container.read(unarchiveMerchantUseCaseProvider)(merchant.id);
      await container.read(getActiveMerchantsUseCaseProvider)();
      await container.read(getArchivedMerchantsUseCaseProvider)();

      // Then
      verify(() => repository.archive(merchant.id, timestamp)).called(1);
      verify(() => repository.unarchive(merchant.id, timestamp)).called(1);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'merchant-archival-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
