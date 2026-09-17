@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AssetValuationCalculator', () {
    const calculator = AssetValuationCalculator();

    final eur = AssetId.fromString('asset-eur');
    final chf = AssetId.fromString('asset-chf');

    test('returns the original amount for same-asset valuation', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('125.40'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result, same(amount));
    });

    test('allows an explicit unit rate for same-asset valuation', () {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('42.75'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
        conversionRate: Decimal.one,
      );

      // Then
      expect(result, same(amount));
    });

    test('rejects a non-unit rate for same-asset valuation', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('100'),
      );

      // When / Then
      expect(
        () => calculator.calculate(
          amount: amount,
          valuationCurrencyId: chf,
          conversionRate: Decimal.parse('1.1'),
        ),
        throwsArgumentError,
      );
    });

    test('converts an incoming amount into the valuation currency', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('80'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
        conversionRate: Decimal.parse('1.25'),
      );

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('100'));
      expect(result.isIncoming, isTrue);
    });

    test('preserves outgoing direction during valuation', () {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.parse('80'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
        conversionRate: Decimal.parse('1.25'),
      );

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('100'));
      expect(result.isOutgoing, isTrue);
    });

    test('values zero without requiring a conversion rate', () {
      // Given
      final amount = AssetAmount.incoming(assetId: eur, amount: Decimal.zero);

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.zero);
      expect(result.isIncoming, isTrue);
    });

    test('preserves the direction of cross-asset zero', () {
      // Given
      final amount = AssetAmount.outgoing(assetId: eur, amount: Decimal.zero);

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.zero);
      expect(result.isOutgoing, isTrue);
    });

    test('propagates an unknown amount without requiring a rate', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.fromInt(-1),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result.assetId, chf);
      expect(result.isUnknownAmount, isTrue);
      expect(result.isIncoming, isTrue);
    });

    test('preserves outgoing direction for an unknown amount', () {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.fromInt(-1),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result.assetId, chf);
      expect(result.isUnknownAmount, isTrue);
      expect(result.isOutgoing, isTrue);
    });

    test('returns an unknown target amount when a cross-asset rate is absent', () {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
      );

      // Then
      expect(result.assetId, chf);
      expect(result.isUnknownAmount, isTrue);
      expect(result.isOutgoing, isTrue);
    });

    test('rejects a zero conversion rate', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      // When / Then
      expect(
        () => calculator.calculate(
          amount: amount,
          valuationCurrencyId: chf,
          conversionRate: Decimal.zero,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative conversion rate', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      // When / Then
      expect(
        () => calculator.calculate(
          amount: amount,
          valuationCurrencyId: chf,
          conversionRate: Decimal.parse('-0.5'),
        ),
        throwsArgumentError,
      );
    });

    test('preserves decimal arithmetic without binary rounding', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('0.1'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
        conversionRate: Decimal.parse('0.2'),
      );

      // Then
      expect(result.amount, Decimal.parse('0.02'));
    });

    test('does not quantize to currency display precision', () {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('10'),
      );

      // When
      final result = calculator.calculate(
        amount: amount,
        valuationCurrencyId: chf,
        conversionRate: Decimal.parse('0.936507936507936507'),
      );

      // Then
      expect(result.amount, Decimal.parse('9.365079365079365070'));
    });
  });
}
