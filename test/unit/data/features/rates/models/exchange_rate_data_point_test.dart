import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_data_point.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('ExchangeRateDataPoint', () {
    final eur = AssetId.fromString('asset-eur');
    final usd = AssetId.fromString('asset-usd');

    test('creates a valid exchange-rate data point', () {
      // Given
      final effectiveAt = DateTime.utc(2026, 9, 17, 8);

      // When
      final dataPoint = ExchangeRateDataPoint(
        baseAssetId: eur,
        quoteAssetId: usd,
        rate: Decimal.parse('1.18'),
        effectiveAt: effectiveAt,
      );

      // Then
      expect(dataPoint.baseAssetId, eur);
      expect(dataPoint.quoteAssetId, usd);
      expect(dataPoint.rate, Decimal.parse('1.18'));
      expect(dataPoint.effectiveAt, effectiveAt);
    });

    test('normalizes effective time to UTC', () {
      // Given
      final effectiveAt = DateTime.parse('2026-09-17T14:30:00+02:00');

      // When
      final dataPoint = ExchangeRateDataPoint(
        baseAssetId: eur,
        quoteAssetId: usd,
        rate: Decimal.parse('1.18'),
        effectiveAt: effectiveAt,
      );

      // Then
      expect(dataPoint.effectiveAt, DateTime.utc(2026, 9, 17, 12, 30));
      expect(dataPoint.effectiveAt.isUtc, isTrue);
    });

    test('rejects identical base and quote assets', () {
      // When
      ExchangeRateDataPoint operation() {
        return ExchangeRateDataPoint(
          baseAssetId: eur,
          quoteAssetId: eur,
          rate: Decimal.parse('1.18'),
          effectiveAt: DateTime.utc(2026, 9, 17),
        );
      }

      // Then
      expect(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'quoteAssetId')
              .having((error) => error.invalidValue, 'invalidValue', eur),
        ),
      );
    });

    test('rejects zero rate', () {
      // When
      ExchangeRateDataPoint operation() {
        return ExchangeRateDataPoint(
          baseAssetId: eur,
          quoteAssetId: usd,
          rate: Decimal.zero,
          effectiveAt: DateTime.utc(2026, 9, 17),
        );
      }

      // Then
      expect(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'rate')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                Decimal.zero,
              ),
        ),
      );
    });

    test('rejects negative rate', () {
      // Given
      final negativeRate = Decimal.parse('-0.01');

      // When
      ExchangeRateDataPoint operation() {
        return ExchangeRateDataPoint(
          baseAssetId: eur,
          quoteAssetId: usd,
          rate: negativeRate,
          effectiveAt: DateTime.utc(2026, 9, 17),
        );
      }

      // Then
      expect(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'rate')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                negativeRate,
              ),
        ),
      );
    });
  });
}
