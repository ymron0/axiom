@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_exchange_rate_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/di/create_exchange_rate_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_at_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_by_id_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_for_pair_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(DateTime.utc(1970));
    registerFallbackValue(exchangeRateFixture());
  });

  group('rate use-case providers', () {
    test('resolves rate use cases from the default dependencies', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final providers = [
        container.read(createExchangeRateUseCaseProvider),
        container.read(getRateAtUseCaseProvider),
        container.read(getRateByIdUseCaseProvider),
        container.read(getRateForPairUseCaseProvider),
      ];

      expect(providers[0], isA<CreateExchangeRateUseCase>());
      expect(providers[1], isA<GetRateAtUseCase>());
      expect(providers[2], isA<GetRateByIdUseCase>());
      expect(providers[3], isA<GetRateForPairUseCase>());
    });

    test('passes an overridden repository to rate use cases', () async {
      final repository = MockRateRepository();
      const failure = RateNotFoundFailure(message: 'rate missing');
      when(() => repository.getAtOrBefore(
        baseAssetId: any(named: 'baseAssetId'),
        quoteAssetId: any(named: 'quoteAssetId'),
        effectiveAt: any(named: 'effectiveAt'),
      )).thenAnswer((_) async => failure);
      final container = ProviderContainer(
        overrides: [rateRepositoryProvider.overrideWithValue(repository)],
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
