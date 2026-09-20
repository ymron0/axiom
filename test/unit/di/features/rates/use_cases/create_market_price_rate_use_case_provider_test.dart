@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/commands/create_market_price_rate_command.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_market_price_rate_use_case.dart';
import 'package:axiom/src/features/rates/di/create_market_price_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/create_rate_service_provider.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/create_rate_service_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(marketPriceRateFixture());
  });

  group('createMarketPriceRateUseCaseProvider', () {
    test(
      'resolves use case with overridden dependencies and succeeds',
      () async {
        // Given
        final mockService = MockCreateRateService();
        final fixedInstant = DateTime.utc(2026, 9, 20, 15);
        final clock = FixedClock(fixedInstant);

        when(() => mockService(any())).thenAnswer(
          (invocation) async =>
              Success(invocation.positionalArguments.whereType<Rate>().first),
        );

        final container = ProviderContainer(
          overrides: [
            createRateServiceProvider.overrideWithValue(mockService),
            clockProvider.overrideWithValue(clock),
          ],
        );
        addTearDown(container.dispose);

        final useCase = container.read(createMarketPriceRateUseCaseProvider);

        // When
        final command = CreateMarketPriceRateCommand(
          baseAssetId: AssetId.fromString('BTC'),
          quoteAssetId: AssetId.fromString('USD'),
          rate: Decimal.parse('65000'),
          effectiveAt: DateTime.utc(2026, 9, 20, 14),
        );
        final result = await useCase(command);

        // Then
        expect(useCase, isA<CreateMarketPriceRateUseCase>());
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.createdAt, fixedInstant);
        verify(() => mockService(any())).called(1);
      },
    );

    test('propagates failures through the resolved use case', () async {
      // Given
      final mockService = MockCreateRateService();
      const failure = RateRepositoryFailure(message: 'Database error');

      when(() => mockService(any())).thenAnswer((_) async => failure);

      final container = ProviderContainer(
        overrides: [createRateServiceProvider.overrideWithValue(mockService)],
      );
      addTearDown(container.dispose);

      final useCase = container.read(createMarketPriceRateUseCaseProvider);

      // When
      final command = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('65000'),
        effectiveAt: DateTime.utc(2026, 9, 20, 14),
      );
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
