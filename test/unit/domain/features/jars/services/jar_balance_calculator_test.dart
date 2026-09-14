@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarBalanceCalculator', () {
    const calculator = JarBalanceCalculator();

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    test('returns zero when there are no allocations', () {
      final result = calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: const [],
      );

      expect(result.assetId, chf);
      expect(result.amount, Decimal.zero);
      expect(result.isIncoming, isTrue);
    });

    test('adds incoming allocations', () {
      final result = calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('500')),
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('250.50')),
        ],
      );

      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('750.50'));
      expect(result.isIncoming, isTrue);
    });

    test('subtracts outgoing allocations', () {
      final result = calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('1000')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('300')),
        ],
      );

      expect(result.amount, Decimal.parse('700'));
      expect(result.isIncoming, isTrue);
    });

    test('can produce an outgoing balance', () {
      final result = calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('200')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('500')),
        ],
      );

      expect(result.amount, Decimal.parse('300'));
      expect(result.isOutgoing, isTrue);
    });

    test('preserves exact decimal precision', () {
      final result = calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('0.1')),
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('0.2')),
        ],
      );

      expect(result.amount, Decimal.parse('0.3'));
    });

    test('rejects allocations using another currency', () {
      expect(
        () => calculator.calculate(
          valuationCurrencyId: chf,
          allocationAmounts: [
            AssetAmount.incoming(assetId: eur, amount: Decimal.parse('100')),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unknown allocation amounts', () {
      expect(
        () => calculator.calculate(
          valuationCurrencyId: chf,
          allocationAmounts: [
            AssetAmount.incoming(assetId: chf, amount: Decimal.fromInt(-1)),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
