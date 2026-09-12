import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/rates/application/commands/create_exchange_rate_command.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_exchange_rate_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/data/repositories/in_memory_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/di/create_exchange_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/create_rate_service_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_at_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_by_id_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_for_pair_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/rates/di/resolve_conversion_rate_service_provider.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
    registerFallbackValue(exchangeRateFixture());
  });

  group('rates providers', () {
    test('resolves all rates providers from the default dependencies', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(rateRepositoryProvider);
      final providers = [
        container.read(createRateServiceProvider),
        container.read(createExchangeRateUseCaseProvider),
        container.read(getRateAtUseCaseProvider),
        container.read(getRateByIdUseCaseProvider),
        container.read(getRateForPairUseCaseProvider),
        container.read(resolveConversionRateServiceProvider),
      ];

      // Then
      expect(repository, isA<InMemoryRateRepositoryImpl>());
      expect(providers[0], isA<CreateRateService>());
      expect(providers[1], isA<CreateExchangeRateUseCase>());
      expect(providers[2], isA<GetRateAtUseCase>());
      expect(providers[3], isA<GetRateByIdUseCase>());
      expect(providers[4], isA<GetRateForPairUseCase>());
      expect(providers[5], isA<ResolveConversionRateService>());
    });

    test('passes an overridden repository to rate use cases', () {
      // Given
      final repository = MockRateRepository();
      final container = ProviderContainer(
        overrides: [rateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // When
      final atUseCase = container.read(getRateAtUseCaseProvider);
      final byIdUseCase = container.read(getRateByIdUseCaseProvider);
      final forPairUseCase = container.read(getRateForPairUseCaseProvider);

      // Then
      expect(atUseCase.repository, same(repository));
      expect(byIdUseCase, isA<GetRateByIdUseCase>());
      expect(forPairUseCase, isA<GetRateForPairUseCase>());
    });

    test('wires overridden dependencies into exchange-rate creation', () async {
      // Given
      final assetRepository = MockAssetRepository();
      final rateRepository = MockRateRepository();
      final timestamp = DateTime.utc(2026, 9, 12, 12);
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'EUR', code: 'EUR'),
              currencyFixture(id: 'USD', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
      when(
        () => rateRepository.create(any()),
      ).thenAnswer((_) async => const Success(null));
      final container = ProviderContainer(
        overrides: [
          assetRepositoryProvider.overrideWithValue(assetRepository),
          rateRepositoryProvider.overrideWithValue(rateRepository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);
      final command = CreateExchangeRateCommand(
        baseAssetId: AssetId.fromString('EUR'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('1.18'),
        effectiveAt: DateTime.utc(2026, 9, 11),
      );

      // When
      final result = await container.read(createExchangeRateUseCaseProvider)(
        command,
      );

      // Then
      final exchangeRate = result.valueOrNull!;
      expect(exchangeRate.createdAt, timestamp);
      expect(exchangeRate.modifiedAt, same(exchangeRate.createdAt));
      verify(() => rateRepository.create(exchangeRate)).called(1);
    });
  });
}
