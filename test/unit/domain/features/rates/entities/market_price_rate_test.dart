@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('MarketPriceRate', () {
    test('creates a new market-price rate with initial metadata', () {
      // Given
      final timestamp = DateTime.parse('2026-09-17T10:00:00Z');

      // When
      final rate = MarketPriceRate.create(
        baseAssetId: AssetId.fromString('asset-btc'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        rate: Decimal.parse('65000'),
        effectiveAt: DateTime.utc(2026, 9, 17, 9),
        clock: FixedClock(timestamp),
      );

      // Then
      expect(rate.id.value, isNotEmpty);
      expect(rate.entityVersion, 1);
      expect(rate.createdAt, timestamp.toUtc());
      expect(rate.modifiedAt, same(rate.createdAt));
    });

    test('uses the default clock when none is supplied', () {
      // When
      final rate = MarketPriceRate.create(
        baseAssetId: AssetId.fromString('asset-btc'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        rate: Decimal.parse('65000'),
        effectiveAt: DateTime.utc(2026, 9, 17, 9),
      );

      // Then
      expect(rate.createdAt.isUtc, isTrue);
      expect(rate.modifiedAt, same(rate.createdAt));
    });

    test('constructs a valid market-price rate', () {
      // Given
      final id = RateId.fromString('rate-btc-usd');
      final btc = AssetId.fromString('asset-btc');
      final usd = AssetId.fromString('asset-usd');
      final value = Decimal.parse('65000');
      final effectiveAt = DateTime.utc(2026, 9, 17, 9);
      final createdAt = DateTime.utc(2026, 9, 17, 12);
      final modifiedAt = DateTime.utc(2026, 9, 17, 12);

      // When
      final rate = MarketPriceRate(
        id: id,
        baseAssetId: btc,
        quoteAssetId: usd,
        rate: value,
        effectiveAt: effectiveAt,
        entityVersion: 2,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

      // Then
      expect(rate, isA<Rate>());
      expect(rate.id, same(id));
      expect(rate.baseAssetId, same(btc));
      expect(rate.quoteAssetId, same(usd));
      expect(rate.rate, value);
      expect(rate.effectiveAt, effectiveAt);
      expect(rate.entityVersion, 2);
      expect(rate.createdAt, same(createdAt));
      expect(rate.modifiedAt, same(modifiedAt));
    });

    test('retains BTC as base and USD as quote for BTC/USD', () {
      // Given
      final btc = AssetId.fromString('asset-btc');
      final usd = AssetId.fromString('asset-usd');
      final value = Decimal.parse('65000');

      // When
      final rate = _createMarketPriceRate(
        baseAssetId: btc,
        quoteAssetId: usd,
        rate: value,
      );

      // Then
      expect(rate.baseAssetId, same(btc));
      expect(rate.quoteAssetId, same(usd));
      expect(rate.rate, value);
    });

    test('round trips through dart_mappable serialization', () {
      // Given
      final rate = _createMarketPriceRate();

      // When
      final decoded = MarketPriceRateMapper.fromJson(rate.toJson());

      // Then
      expect(decoded, isA<MarketPriceRate>());
      expect(decoded, rate);
      expect(decoded.id, rate.id);
      expect(decoded.baseAssetId, rate.baseAssetId);
      expect(decoded.quoteAssetId, rate.quoteAssetId);
      expect(decoded.rate, rate.rate);
      expect(decoded.effectiveAt, rate.effectiveAt);
    });

    test('compares equivalent market-price rates by mapped values', () {
      // Given
      final first = _createMarketPriceRate();
      final equivalent = _createMarketPriceRate();

      // Then
      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
    });

    test('distinguishes market-price rates with different identities', () {
      // Given
      final first = _createMarketPriceRate();
      final differentIdentity = _createMarketPriceRate(
        id: RateId.fromString('rate-btc-usd-2'),
      );

      // Then
      expect(first, isNot(differentIdentity));
    });

    test('distinguishes market-price rates with different domain state', () {
      // Given
      final rate = _createMarketPriceRate();
      final differentRate = _createMarketPriceRate(
        rate: Decimal.parse('66000'),
      );
      final reversedPair = _createMarketPriceRate(
        baseAssetId: AssetId.fromString('asset-usd'),
        quoteAssetId: AssetId.fromString('asset-btc'),
        rate: Decimal.parse('0.0000154'),
      );
      final differentEffectiveAt = _createMarketPriceRate(
        effectiveAt: DateTime.utc(2026, 9, 18),
      );

      // Then
      expect(rate, isNot(differentRate));
      expect(rate, isNot(reversedPair));
      expect(rate, isNot(differentEffectiveAt));
    });

    test('is distinct from an ExchangeRate with identical field values', () {
      // Given
      final btc = AssetId.fromString('asset-btc');
      final usd = AssetId.fromString('asset-usd');
      final id = RateId.fromString('rate-btc-usd');
      final value = Decimal.parse('65000');
      final effectiveAt = DateTime.utc(2026, 9, 17, 9);
      final ts = DateTime.utc(2026, 9, 17, 12);

      final marketPriceRate = MarketPriceRate(
        id: id,
        baseAssetId: btc,
        quoteAssetId: usd,
        rate: value,
        effectiveAt: effectiveAt,
        entityVersion: 1,
        createdAt: ts,
        modifiedAt: ts,
      );

      final exchangeRate = ExchangeRate(
        id: id,
        baseAssetId: btc,
        quoteAssetId: usd,
        rate: value,
        effectiveAt: effectiveAt,
        entityVersion: 1,
        createdAt: ts,
        modifiedAt: ts,
      );

      // Then
      expect(marketPriceRate, isNot(exchangeRate));
    });

    test(
      'copyWith returns a MarketPriceRate with only the requested change',
      () {
        // Given
        final rate = _createMarketPriceRate();
        final updatedValue = Decimal.parse('66000');

        // When
        final updated = rate.copyWith(rate: updatedValue);

        // Then
        expect(updated, isA<MarketPriceRate>());
        expect(updated.rate, updatedValue);
        expect(updated.id, rate.id);
        expect(updated.baseAssetId, rate.baseAssetId);
        expect(updated.quoteAssetId, rate.quoteAssetId);
        expect(updated.effectiveAt, rate.effectiveAt);
        expect(updated.entityVersion, rate.entityVersion);
        expect(updated.createdAt, rate.createdAt);
        expect(updated.modifiedAt, rate.modifiedAt);
      },
    );

    test('normalizes a non-UTC effectiveAt to UTC', () {
      // Given
      final localTime = DateTime(2026, 9, 17, 12); // local, unspecified zone

      // When
      final rate = _createMarketPriceRate(effectiveAt: localTime);

      // Then
      expect(rate.effectiveAt.isUtc, isTrue);
    });

    group('invariants', () {
      test('rejects a zero rate', () {
        expect(
          () => _createMarketPriceRate(rate: Decimal.zero),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'rate')
                .having((e) => e.invalidValue, 'invalidValue', Decimal.zero),
          ),
        );
      });

      test('rejects a negative rate', () {
        expect(
          () => _createMarketPriceRate(rate: Decimal.parse('-1')),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'rate')),
        );
      });

      test('rejects identical base and quote assets', () {
        expect(
          () => _createMarketPriceRate(
            quoteAssetId: AssetId.fromString('asset-btc'),
          ),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'quoteAssetId'),
          ),
        );
      });
    });
  });
}

MarketPriceRate _createMarketPriceRate({
  RateId? id,
  AssetId? baseAssetId,
  AssetId? quoteAssetId,
  Decimal? rate,
  DateTime? effectiveAt,
}) {
  return MarketPriceRate(
    id: id ?? RateId.fromString('rate-btc-usd'),
    baseAssetId: baseAssetId ?? AssetId.fromString('asset-btc'),
    quoteAssetId: quoteAssetId ?? AssetId.fromString('asset-usd'),
    rate: rate ?? Decimal.parse('65000'),
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 9),
    entityVersion: 1,
    createdAt: DateTime.utc(2026, 9, 17, 12),
    modifiedAt: DateTime.utc(2026, 9, 17, 12),
  );
}
