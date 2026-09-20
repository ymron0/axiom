@Tags(['application'])
library;

import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/invalid_rate_asset_semantics_failure.dart';
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

    group('ExchangeRate', () {
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

      test(
        'rejects an ExchangeRate whose base asset is a CryptoAsset',
        () async {
          // Given
          final rate = exchangeRateFixture(baseAssetId: 'BTC');
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  cryptoAssetFixture(id: 'BTC', code: 'BTC'),
                  currencyFixture(id: 'USD', code: 'USD'),
                ],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());
          expect(
            result.failureOrNull!.message,
            contains('Exchange-rate base asset must be a Currency'),
          );
        },
      );

      test(
        'rejects an ExchangeRate whose quote asset is a CryptoAsset',
        () async {
          // Given
          final rate = exchangeRateFixture(quoteAssetId: 'BTC');
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  currencyFixture(id: 'EUR', code: 'EUR'),
                  cryptoAssetFixture(id: 'BTC', code: 'BTC'),
                ],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());
          expect(
            result.failureOrNull!.message,
            contains('Exchange-rate quote asset must be a Currency'),
          );
        },
      );
    });

    group('MarketPriceRate', () {
      test(
        'accepts a MarketPriceRate with a CryptoAsset base and Currency quote',
        () async {
          // Given
          final rate = marketPriceRateFixture(
            baseAssetId: 'BTC',
            quoteAssetId: 'USD',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  cryptoAssetFixture(id: 'BTC', code: 'BTC'),
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
        },
      );

      test(
        'accepts a MarketPriceRate with a StockAsset base and Currency quote',
        () async {
          // Given
          final rate = marketPriceRateFixture(
            baseAssetId: 'NVDA',
            quoteAssetId: 'USD',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  stockAssetFixture(id: 'NVDA', code: 'NVDA'),
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
        },
      );

      test(
        'accepts a MarketPriceRate with a CommodityAsset base and Currency quote',
        () async {
          // Given
          final rate = marketPriceRateFixture(
            baseAssetId: 'XAU',
            quoteAssetId: 'USD',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  commodityAssetFixture(id: 'XAU', code: 'XAU'),
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
        },
      );

      test('rejects a MarketPriceRate whose base asset is a Currency', () async {
        // Given
        final rate = marketPriceRateFixture(
          baseAssetId: 'EUR',
          quoteAssetId: 'USD',
        );
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
        expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());
        expect(
          result.failureOrNull!.message,
          contains(
            'Market-price base asset must be a market-priced non-currency asset',
          ),
        );
      });

      test(
        'rejects a MarketPriceRate whose quote asset is not a Currency',
        () async {
          // Given
          final rate = marketPriceRateFixture(
            baseAssetId: 'BTC',
            quoteAssetId: 'ETH',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [
                  cryptoAssetFixture(id: 'BTC', code: 'BTC'),
                  cryptoAssetFixture(id: 'ETH', code: 'ETH'),
                ],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());
          expect(
            result.failureOrNull!.message,
            contains('Market-price quote asset must be a Currency'),
          );
        },
      );
    });

    group('referential integrity', () {
      test(
        'rejects an exchange rate with a missing referenced asset',
        () async {
          // Given
          final rate = exchangeRateFixture();
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async =>
                Success(BatchLookup(found: [], missing: [rate.baseAssetId])),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
        },
      );

      test(
        'rejects when the base asset is absent from the lookup result map',
        () async {
          // Given — missing is empty but found does not contain the base asset
          final rate = exchangeRateFixture(
            baseAssetId: 'EUR',
            quoteAssetId: 'USD',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [currencyFixture(id: 'USD', code: 'USD')],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
          expect(
            result.failureOrNull!.message,
            contains('base asset was not found'),
          );
        },
      );

      test(
        'rejects when the quote asset is absent from the lookup result map',
        () async {
          // Given — missing is empty but found does not contain the quote asset
          final rate = exchangeRateFixture(
            baseAssetId: 'EUR',
            quoteAssetId: 'USD',
          );
          when(() => repository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup(
                found: [currencyFixture(id: 'EUR', code: 'EUR')],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service([rate]);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
          expect(
            result.failureOrNull!.message,
            contains('quote asset was not found'),
          );
        },
      );

      test('returns success immediately when the rate list is empty', () async {
        // Given / When
        final result = await service([]);

        // Then
        expect(result.isSuccess, isTrue);
        verifyNever(() => repository.getByIds(any()));
      });

      test('propagates an asset lookup failure unchanged', () async {
        // Given
        final rate = exchangeRateFixture();
        const failure = AssetNotFoundFailure(message: 'lookup failed');
        when(() => repository.getByIds(any())).thenAnswer((_) async => failure);

        // When
        final result = await service([rate]);

        // Then
        expect(result.failureOrNull, same(failure));
      });
    });
  });
}
