import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('ExchangeRate', () {
    test('generates a new exchange rate with initial metadata', () {
      // Given
      final timestamp = DateTime.parse('2024-01-16T12:30:00+02:00');

      // When
      final exchangeRate = ExchangeRate.generate(
        baseAssetId: AssetId.fromString('asset-eur'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        rate: Decimal.parse('1.18'),
        effectiveAt: DateTime.utc(2024, 1, 15),
        clock: FixedClock(timestamp),
      );

      // Then
      expect(exchangeRate.id.value, isNotEmpty);
      expect(exchangeRate.entityVersion, 1);
      expect(exchangeRate.createdAt, timestamp.toUtc());
      expect(exchangeRate.modifiedAt, same(exchangeRate.createdAt));
    });

    test('constructs a valid exchange rate', () {
      // Given
      final id = RateId.fromString('rate-eur-usd');
      final eur = AssetId.fromString('asset-eur');
      final usd = AssetId.fromString('asset-usd');
      final value = Decimal.parse('1.18');
      final effectiveAt = DateTime.utc(2024, 1, 15);
      final createdAt = DateTime.utc(2024, 1, 16);
      final modifiedAt = DateTime.utc(2024, 1, 17);

      // When
      final exchangeRate = ExchangeRate(
        id: id,
        baseAssetId: eur,
        quoteAssetId: usd,
        rate: value,
        effectiveAt: effectiveAt,
        entityVersion: 2,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

      // Then
      expect(exchangeRate, isA<Rate>());
      expect(exchangeRate.id, same(id));
      expect(exchangeRate.baseAssetId, same(eur));
      expect(exchangeRate.quoteAssetId, same(usd));
      expect(exchangeRate.rate, value);
      expect(exchangeRate.effectiveAt, effectiveAt);
      expect(exchangeRate.entityVersion, 2);
      expect(exchangeRate.createdAt, same(createdAt));
      expect(exchangeRate.modifiedAt, same(modifiedAt));
    });

    test('retains EUR as base and USD as quote for EUR/USD', () {
      // Given
      final eur = AssetId.fromString('asset-eur');
      final usd = AssetId.fromString('asset-usd');
      final value = Decimal.parse('1.18');

      // When
      final exchangeRate = _createExchangeRate(
        baseAssetId: eur,
        quoteAssetId: usd,
        rate: value,
      );

      // Then
      expect(exchangeRate.baseAssetId, same(eur));
      expect(exchangeRate.quoteAssetId, same(usd));
      expect(exchangeRate.rate, value);
    });

    test('round trips through dart_mappable serialization', () {
      // Given
      final exchangeRate = _createExchangeRate();

      // When
      final decoded = ExchangeRateMapper.fromJson(exchangeRate.toJson());

      // Then
      expect(decoded, isA<ExchangeRate>());
      expect(decoded, exchangeRate);
      expect(decoded.id, exchangeRate.id);
      expect(decoded.baseAssetId, exchangeRate.baseAssetId);
      expect(decoded.quoteAssetId, exchangeRate.quoteAssetId);
      expect(decoded.rate, exchangeRate.rate);
      expect(decoded.effectiveAt, exchangeRate.effectiveAt);
    });

    test('compares equivalent exchange rates by mapped values', () {
      // Given
      final first = _createExchangeRate();
      final equivalent = _createExchangeRate();

      // Then
      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
    });

    test('distinguishes exchange rates with different identities', () {
      // Given
      final first = _createExchangeRate();
      final differentIdentity = _createExchangeRate(
        id: RateId.fromString('rate-eur-usd-2'),
      );

      // Then
      expect(first, isNot(differentIdentity));
    });

    test('distinguishes exchange rates with different domain state', () {
      // Given
      final exchangeRate = _createExchangeRate();
      final differentRate = _createExchangeRate(rate: Decimal.parse('1.19'));
      final reversedPair = _createExchangeRate(
        baseAssetId: AssetId.fromString('asset-usd'),
        quoteAssetId: AssetId.fromString('asset-eur'),
        rate: Decimal.parse('0.8474576271'),
      );
      final differentEffectiveAt = _createExchangeRate(
        effectiveAt: DateTime.utc(2024, 1, 16),
      );

      // Then
      expect(exchangeRate, isNot(differentRate));
      expect(exchangeRate, isNot(reversedPair));
      expect(exchangeRate, isNot(differentEffectiveAt));
    });

    test('copyWith returns an ExchangeRate with only the requested change', () {
      // Given
      final exchangeRate = _createExchangeRate();
      final updatedValue = Decimal.parse('1.19');

      // When
      final updated = exchangeRate.copyWith(rate: updatedValue);

      // Then
      expect(updated, isA<ExchangeRate>());
      expect(updated.rate, updatedValue);
      expect(updated.id, exchangeRate.id);
      expect(updated.baseAssetId, exchangeRate.baseAssetId);
      expect(updated.quoteAssetId, exchangeRate.quoteAssetId);
      expect(updated.effectiveAt, exchangeRate.effectiveAt);
      expect(updated.entityVersion, exchangeRate.entityVersion);
      expect(updated.createdAt, exchangeRate.createdAt);
      expect(updated.modifiedAt, exchangeRate.modifiedAt);
    });

    test('copyWith rejects a zero rate', () {
      // Given
      final exchangeRate = _createExchangeRate();

      // When / Then
      expect(
        () => exchangeRate.copyWith(rate: Decimal.zero),
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

    test('copyWith rejects identical base and quote assets', () {
      // Given
      final exchangeRate = _createExchangeRate();

      // When / Then
      expect(
        () => exchangeRate.copyWith(
          quoteAssetId: exchangeRate.baseAssetId,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'quoteAssetId')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                exchangeRate.baseAssetId,
              ),
        ),
      );
    });
  });
}

ExchangeRate _createExchangeRate({
  RateId? id,
  AssetId? baseAssetId,
  AssetId? quoteAssetId,
  Decimal? rate,
  DateTime? effectiveAt,
}) {
  return ExchangeRate(
    id: id ?? RateId.fromString('rate-eur-usd'),
    baseAssetId: baseAssetId ?? AssetId.fromString('asset-eur'),
    quoteAssetId: quoteAssetId ?? AssetId.fromString('asset-usd'),
    rate: rate ?? Decimal.parse('1.18'),
    effectiveAt: effectiveAt ?? DateTime.utc(2024, 1, 15),
    entityVersion: 1,
    createdAt: DateTime.utc(2024, 1, 16),
    modifiedAt: DateTime.utc(2024, 1, 16),
  );
}
