@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_exchange_rate_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_market_price_rate_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/di/create_exchange_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/create_market_price_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_at_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_by_id_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_for_pair_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  late String rootPath;
  late Directory rootDirectory;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(DateTime.utc(1970));
    registerFallbackValue(exchangeRateFixture());
  });

  setUp(() async {
    rootPath = _uniqueRootPath();
    rootDirectory = Directory(rootPath);
    container = ProviderContainer(
      overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
    );
    final lifecycleService = container.read(databaseLifecycleServiceProvider);

    expect((await lifecycleService.open()).isSuccess, isTrue);
  });

  tearDown(() async {
    final lifecycleService = container.read(databaseLifecycleServiceProvider);

    await lifecycleService.close();
    container.dispose();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  group('rate use-case providers', () {
    test('resolves rate use cases from the default dependencies', () {
      final providers = [
        container.read(createExchangeRateUseCaseProvider),
        container.read(createMarketPriceRateUseCaseProvider),
        container.read(getRateAtUseCaseProvider),
        container.read(getRateByIdUseCaseProvider),
        container.read(getRateForPairUseCaseProvider),
      ];

      expect(providers[0], isA<CreateExchangeRateUseCase>());
      expect(providers[1], isA<CreateMarketPriceRateUseCase>());
      expect(providers[2], isA<GetRateAtUseCase>());
      expect(providers[3], isA<GetRateByIdUseCase>());
      expect(providers[4], isA<GetRateForPairUseCase>());
    });

    test('passes an overridden repository to rate use cases', () async {
      final repository = MockRateRepository();
      const failure = RateNotFoundFailure(message: 'rate missing');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
          effectiveAt: any(named: 'effectiveAt'),
        ),
      ).thenAnswer((_) async => failure);
      final container = ProviderContainer(
        overrides: [
          assetRepositoryProvider.overrideWithValue(MockAssetRepository()),
          rateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final atUseCase = container.read(getRateAtUseCaseProvider);
      final byIdUseCase = container.read(getRateByIdUseCaseProvider);
      final forPairUseCase = container.read(getRateForPairUseCaseProvider);
      final result = await atUseCase(
        baseAssetId: AssetId.fromString('asset-eur'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        at: DateTime.utc(2026, 9, 12),
      );

      expect(result.failureOrNull, same(failure));
      expect(byIdUseCase, isA<GetRateByIdUseCase>());
      expect(forPairUseCase, isA<GetRateForPairUseCase>());
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'rate-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
