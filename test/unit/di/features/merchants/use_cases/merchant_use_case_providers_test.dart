@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/create_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/delete_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchant_by_id_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/restore_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/search_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/update_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/data/repositories/sembast_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/di/create_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/delete_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_merchant_by_id_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:axiom/src/features/merchants/di/restore_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/search_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/update_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('merchant use-case providers', () {
    setUpAll(() {
      registerFallbackValue(merchantFixture(id: 'fallback'));
    });

    test('resolves every use case from the default repository', () async {
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

      // When
      expect((await lifecycleService.open()).isSuccess, isTrue);
      final repository = container.read(merchantRepositoryProvider);
      final useCases = [
        container.read(createMerchantUseCaseProvider),
        container.read(getMerchantsUseCaseProvider),
        container.read(getMerchantByIdUseCaseProvider),
        container.read(searchMerchantsUseCaseProvider),
        container.read(updateMerchantUseCaseProvider),
        container.read(deleteMerchantUseCaseProvider),
        container.read(restoreMerchantUseCaseProvider),
      ];

      // Then
      expect(repository, isA<SembastMerchantRepositoryImpl>());
      expect(useCases, hasLength(7));
      expect(useCases[0], isA<CreateMerchantUseCase>());
      expect(useCases[1], isA<GetMerchantsUseCase>());
      expect(useCases[2], isA<GetMerchantByIdUseCase>());
      expect(useCases[3], isA<SearchMerchantsUseCase>());
      expect(useCases[4], isA<UpdateMerchantUseCase>());
      expect(useCases[5], isA<DeleteMerchantUseCase>());
      expect(useCases[6], isA<RestoreMerchantUseCase>());
    });

    test('injects an overridden repository into every use case', () async {
      // Given
      final repository = MockMerchantRepository();
      final merchant = merchantFixture(id: 'provider-merchant');
      final deleted = merchantFixture(
        id: 'provider-deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      final merchants = [merchant];
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Merchant>>(merchants));
      when(
        () => repository.getById(merchant.id),
      ).thenAnswer((_) async => Success<Merchant?>(merchant));
      when(
        () => repository.search('merchant'),
      ).thenAnswer((_) async => Success<List<Merchant>>(merchants));
      when(
        () => repository.update(merchant),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.delete(merchant.id),
      ).thenAnswer((_) async => Success(merchant));
      when(
        () => repository.restore(deleted),
      ).thenAnswer((_) async => const Success(null));
      final container = ProviderContainer(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 1, 1)),
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final created = await container.read(createMerchantUseCaseProvider)(
        'Created merchant',
      );
      await container.read(getMerchantsUseCaseProvider)();
      await container.read(getMerchantByIdUseCaseProvider)(merchant.id);
      await container.read(searchMerchantsUseCaseProvider)('merchant');
      await container.read(updateMerchantUseCaseProvider)(merchant);
      await container.read(deleteMerchantUseCaseProvider)(merchant.id);
      await container.read(restoreMerchantUseCaseProvider)(deleted);

      // Then
      verify(() => repository.create(created.valueOrNull!)).called(1);
      verify(() => repository.getAll()).called(1);
      verify(() => repository.getById(merchant.id)).called(1);
      verify(() => repository.search('merchant')).called(1);
      verify(() => repository.update(merchant)).called(1);
      verify(() => repository.delete(merchant.id)).called(1);
      verify(() => repository.restore(deleted)).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'merchant-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
