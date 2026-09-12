import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
  });

  group('ValidateRateAssetsService', () {
    late MockAssetRepository repository;
    late ValidateRateAssetsService service;

    setUp(() {
      repository = MockAssetRepository();
      service = ValidateRateAssetsService(
        getAssetsByIds: GetAssetsByIdsUseCase(repository),
      );
    });

    test(
      'accepts exchange rates whose referenced assets are currencies',
      () async {
        // Given
        final rate = exchangeRateFixture();
        when(() => repository.getByIds(any())).thenAnswer(
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

        // When
        final result = await service([rate]);

        // Then
        expect(result.isSuccess, isTrue);
        final captured = verify(
          () => repository.getByIds(captureAny()),
        ).captured.single;
        expect(captured, [rate.baseAssetId, rate.quoteAssetId]);
      },
    );

    test('deduplicates referenced assets across exchange rates', () async {
      // Given
      final first = exchangeRateFixture(id: 'rate-1');
      final second = exchangeRateFixture(id: 'rate-2');
      when(() => repository.getByIds(any())).thenAnswer(
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

      // When
      await service([first, second]);

      // Then
      final captured = verify(
        () => repository.getByIds(captureAny()),
      ).captured.single;
      expect(captured, [first.baseAssetId, first.quoteAssetId]);
    });

    test('rejects an exchange rate with a missing referenced asset', () async {
      // Given
      final rate = exchangeRateFixture();
      when(() => repository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(found: [], missing: [rate.baseAssetId]),
        ),
      );

      // When
      final result = await service([rate]);

      // Then
      expect(result.failureOrNull, isA<RecordNotFoundFailure>());
    });

    test('propagates an asset lookup failure unchanged', () async {
      // Given
      final rate = exchangeRateFixture();
      const failure = UnexpectedPersistenceFailure(message: 'lookup failed');
      when(
        () => repository.getByIds(any()),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service([rate]);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
