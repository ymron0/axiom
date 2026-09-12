import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

part 'rate_test.mapper.dart';

void main() {
  group('Rate', () {
    test('generates metadata for a new rate', () {
      // Given
      final timestamp = DateTime.parse('2024-01-15T12:30:00+02:00');

      // When
      final rate = TestRate.generate(
        baseAssetId: AssetId.fromString('asset-btc'),
        quoteAssetId: AssetId.fromString('asset-usd'),
        rate: Decimal.parse('65000'),
        effectiveAt: DateTime.utc(2024, 1, 14),
        clock: FixedClock(timestamp),
      );

      // Then
      expect(rate.id.value, isNotEmpty);
      expect(rate.entityVersion, 1);
      expect(rate.createdAt, timestamp.toUtc());
      expect(rate.modifiedAt, timestamp.toUtc());
      expect(rate.modifiedAt, same(rate.createdAt));
    });

    test('preserves the ordered asset pair, value, and audit metadata', () {
      // Given
      final id = RateId.fromString('rate-btc-usd');
      final baseAssetId = AssetId.fromString('asset-btc');
      final quoteAssetId = AssetId.fromString('asset-usd');
      final value = Decimal.parse('65000.25');
      final createdAt = DateTime.utc(2024, 1, 1);
      final modifiedAt = DateTime.utc(2024, 1, 2);

      // When
      final rate = TestRate(
        id: id,
        baseAssetId: baseAssetId,
        quoteAssetId: quoteAssetId,
        rate: value,
        effectiveAt: DateTime.utc(2023, 12, 31),
        entityVersion: 2,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

      // Then
      expect(rate.id, same(id));
      expect(rate.baseAssetId, same(baseAssetId));
      expect(rate.quoteAssetId, same(quoteAssetId));
      expect(rate.rate, value);
      expect(rate.entityVersion, 2);
      expect(rate.createdAt, same(createdAt));
      expect(rate.modifiedAt, same(modifiedAt));
    });

    test('normalizes the effective instant to UTC', () {
      // Given
      final effectiveAt = DateTime.parse('2024-01-15T12:30:00+02:00');

      // When
      final rate = _createRate(effectiveAt: effectiveAt);

      // Then
      expect(rate.effectiveAt, DateTime.utc(2024, 1, 15, 10, 30));
      expect(rate.effectiveAt.isUtc, isTrue);
    });

    test(
      'constructs a concrete rate with a positive value and distinct assets',
      () {
        // Given
        final value = Decimal.parse('0.00000001');

        // When
        final rate = _createRate(rate: value);

        // Then
        expect(rate, isA<Rate>());
        expect(rate.rate, value);
        expect(rate.baseAssetId, isNot(rate.quoteAssetId));
      },
    );

    test('retains BTC/USD base, quote, and rate semantics', () {
      // Given
      final btc = AssetId.fromString('asset-btc');
      final usd = AssetId.fromString('asset-usd');
      final value = Decimal.fromInt(65000);

      // When
      final rate = _createRate(
        baseAssetId: btc,
        quoteAssetId: usd,
        rate: value,
      );

      // Then
      expect(rate.baseAssetId, same(btc));
      expect(rate.quoteAssetId, same(usd));
      expect(rate.rate, value);
    });

    test('accepts equal creation and modification instants', () {
      // Given
      final timestamp = DateTime.utc(2024, 1, 1);

      // When
      final rate = _createRate(createdAt: timestamp, modifiedAt: timestamp);

      // Then
      expect(rate.createdAt, timestamp);
      expect(rate.modifiedAt, timestamp);
    });

    test('rejects asset identifiers representing the same asset', () {
      // Given
      final baseAssetId = AssetId.fromString('asset-usd');
      final equivalentQuoteAssetId = AssetId.fromString('asset-usd');

      // When / Then
      expect(
        () => _createRate(
          baseAssetId: baseAssetId,
          quoteAssetId: equivalentQuoteAssetId,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'quoteAssetId')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                equivalentQuoteAssetId,
              ),
        ),
      );
    });

    test('rejects a zero rate value', () {
      // Given
      final value = Decimal.zero;

      // When / Then
      expect(
        () => _createRate(rate: value),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'rate')
              .having((error) => error.invalidValue, 'invalidValue', value),
        ),
      );
    });

    test('rejects a negative rate value', () {
      // Given
      final value = Decimal.parse('-0.00000001');

      // When / Then
      expect(
        () => _createRate(rate: value),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'rate')
              .having((error) => error.invalidValue, 'invalidValue', value),
        ),
      );
    });

    test('rejects entity versions below one', () {
      // Given / When / Then
      for (final entityVersion in [0, -1]) {
        expect(
          () => _createRate(entityVersion: entityVersion),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'entityVersion')
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  entityVersion,
                ),
          ),
          reason: 'Expected version $entityVersion to be rejected.',
        );
      }
    });

    test('rejects a modification instant before the creation instant', () {
      // Given
      final createdAt = DateTime.utc(2024, 1, 2);
      final modifiedAt = DateTime.utc(2024, 1, 1);

      // When / Then
      expect(
        () => _createRate(createdAt: createdAt, modifiedAt: modifiedAt),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'modifiedAt')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                modifiedAt,
              ),
        ),
      );
    });

    test('uses mapped equality across identity and domain state', () {
      // Given
      final rate = _createRate();
      final equivalent = _createRate();
      final differentIdentity = _createRate(
        id: RateId.fromString('rate-btc-usd-2'),
      );
      final differentDomainState = _createRate(
        rate: Decimal.fromInt(65001),
      );

      // Then
      expect(rate, equivalent);
      expect(rate.hashCode, equivalent.hashCode);
      expect(rate, isNot(differentIdentity));
      expect(rate, isNot(differentDomainState));
    });
  });
}

TestRate _createRate({
  RateId? id,
  AssetId? baseAssetId,
  AssetId? quoteAssetId,
  Decimal? rate,
  DateTime? effectiveAt,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  return TestRate(
    id: id ?? RateId.fromString('rate-btc-usd'),
    baseAssetId: baseAssetId ?? AssetId.fromString('asset-btc'),
    quoteAssetId: quoteAssetId ?? AssetId.fromString('asset-usd'),
    rate: rate ?? Decimal.parse('65000'),
    effectiveAt: effectiveAt ?? DateTime.utc(2024, 1, 1),
    entityVersion: entityVersion,
    createdAt: createdAt ?? DateTime.utc(2024, 1, 1),
    modifiedAt: modifiedAt ?? DateTime.utc(2024, 1, 1),
  );
}

@MappableClass(includeCustomMappers: [DecimalMapper()])
final class TestRate extends Rate with TestRateMappable {
  @MappableConstructor()
  TestRate({
    required super.id,
    required super.baseAssetId,
    required super.quoteAssetId,
    required super.rate,
    required super.effectiveAt,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
  });

  TestRate.generate({
    required super.baseAssetId,
    required super.quoteAssetId,
    required super.rate,
    required super.effectiveAt,
    required super.clock,
  }) : super.generate();
}
