@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/application/commands/create_exchange_rate_command.dart';
import 'package:axiom/src/features/rates/di/create_rate_service_provider.dart';
import 'package:axiom/src/features/rates/di/create_exchange_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';



void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(<AssetId>[]);
  });

  group('rate service providers', () {
    test('resolves rate services from the default dependencies', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(createRateServiceProvider), isA<CreateRateService>());
      expect(
        container.read(resolveConversionRateServiceProvider),
        isA<ResolveConversionRateService>(),
      );
    });

    test('wires overridden dependencies into exchange-rate creation', () async {
      final assetRepository = MockAssetRepository();
      final rateRepository = MockRateRepository();
      final timestamp = DateTime.utc(2026, 9, 12, 12);
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'asset-eur', code: 'EUR'),
              currencyFixture(id: 'asset-usd', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
      when(() => rateRepository.create(any())).thenAnswer(
        (_) async => const Success(null),
      );
      final container = ProviderContainer(
        overrides: [
          assetRepositoryProvider.overrideWithValue(assetRepository),
          rateRepositoryProvider.overrideWithValue(rateRepository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);
      final command = CreateExchangeRateCommand(
        baseAssetId: AssetId.fromString('asset-eur'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        rate: Decimal.parse('1.18'),
        effectiveAt: DateTime.utc(2026, 9, 11),
      );

      final result = await container.read(createExchangeRateUseCaseProvider)(command);

      final exchangeRate = result.valueOrNull!;
      expect(exchangeRate.createdAt, timestamp);
      expect(exchangeRate.modifiedAt, same(exchangeRate.createdAt));
      verify(() => rateRepository.create(exchangeRate)).called(1);
    });
  });
}
