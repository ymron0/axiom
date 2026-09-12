import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/commands/create_exchange_rate_command.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_exchange_rate_use_case.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
    registerFallbackValue(exchangeRateFixture());
  });

  group('CreateExchangeRateUseCase', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository rateRepository;
    late CreateExchangeRateUseCase useCase;
    late DateTime timestamp;

    setUp(() {
      assetRepository = MockAssetRepository();
      rateRepository = MockRateRepository();
      timestamp = DateTime.utc(2026, 9, 12, 10);
      useCase = CreateExchangeRateUseCase(
        createRate: CreateRateService(
          repository: rateRepository,
          validateRateAssets: ValidateRateAssetsService(
            getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
          ),
          canonicalBridgeAssetId: AssetId.fromString('USD'),
        ),
        clock: FixedClock(timestamp),
      );
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
    });

    test('generates and persists a new exchange rate', () async {
      // Given
      final command = CreateExchangeRateCommand(
        baseAssetId: AssetId.fromString('EUR'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('1.18'),
        effectiveAt: DateTime.utc(2026, 9, 11),
      );
      when(
        () => rateRepository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final exchangeRate = result.valueOrNull!;
      expect(exchangeRate.id.value, isNotEmpty);
      expect(exchangeRate.entityVersion, 1);
      expect(exchangeRate.createdAt, timestamp);
      expect(exchangeRate.modifiedAt, same(exchangeRate.createdAt));
      expect(exchangeRate.baseAssetId, command.baseAssetId);
      expect(exchangeRate.quoteAssetId, command.quoteAssetId);
      expect(exchangeRate.rate, command.rate);
      expect(exchangeRate.effectiveAt, command.effectiveAt);
      verify(() => rateRepository.create(exchangeRate)).called(1);
    });

    test('propagates persistence failures unchanged', () async {
      // Given
      final command = CreateExchangeRateCommand(
        baseAssetId: AssetId.fromString('EUR'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('1.18'),
        effectiveAt: DateTime.utc(2026, 9, 11),
      );
      const failure = UnexpectedPersistenceFailure(message: 'write failed');
      when(() => rateRepository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
