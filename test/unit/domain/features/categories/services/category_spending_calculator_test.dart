@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CategorySpendingCalculator', () {
    const calculator = CategorySpendingCalculator();

    final categoryId = CategoryId.fromString('groceries');
    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    test('returns outgoing zero totals for an empty expense category', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: const [],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.assetId, chf);
      expect(result.directTotal.amount, Decimal.zero);
      expect(result.directTotal.isOutgoing, isTrue);

      expect(result.aggregateTotal.assetId, chf);
      expect(result.aggregateTotal.amount, Decimal.zero);
      expect(result.aggregateTotal.isOutgoing, isTrue);
    });

    test('returns incoming zero totals for an empty income category', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.income,
        valuationCurrencyId: chf,
        directAllocationAmounts: const [],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.zero);
      expect(result.directTotal.isIncoming, isTrue);
      expect(result.aggregateTotal.amount, Decimal.zero);
      expect(result.aggregateTotal.isIncoming, isTrue);
    });

    test('adds direct expense allocations exactly', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('100.25')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('20.10')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('5.35')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('125.70'));
      expect(result.aggregateTotal.amount, Decimal.parse('125.70'));
    });

    test('adds child allocations only to the aggregate total', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('100')),
        ],
        childAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('25')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('40.50')),
        ],
      );

      expect(result.directTotal.amount, Decimal.parse('100'));
      expect(result.aggregateTotal.amount, Decimal.parse('165.50'));
    });

    test('preserves exact decimal precision', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('0.1')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('0.2')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('0.3'));
    });

    test('produces the same totals regardless of allocation order', () {
      final first = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('100.25'),
      );
      final second = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('20.10'),
      );
      final third = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('5.35'),
      );

      final forward = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [first, second, third],
        childAllocationAmounts: const [],
      );

      final reversed = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [third, second, first],
        childAllocationAmounts: const [],
      );

      expect(forward.directTotal.amount, Decimal.parse('125.70'));
      expect(reversed.directTotal.amount, forward.directTotal.amount);
      expect(reversed.aggregateTotal.amount, forward.aggregateTotal.amount);
    });

    test('adds income allocations as incoming magnitudes', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.income,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('4000')),
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('250.50')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('4250.50'));
      expect(result.directTotal.isIncoming, isTrue);
      expect(result.aggregateTotal.isIncoming, isTrue);
    });

    test('rejects a direct allocation using another asset', () {
      expect(
        () => calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: [
            AssetAmount.outgoing(assetId: eur, amount: Decimal.parse('100')),
          ],
          childAllocationAmounts: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a child allocation using another asset', () {
      expect(
        () => calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: const [],
          childAllocationAmounts: [
            AssetAmount.outgoing(assetId: eur, amount: Decimal.parse('100')),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown allocation amount', () {
      expect(
        () => calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: [
            AssetAmount.outgoing(assetId: chf, amount: Decimal.fromInt(-1)),
          ],
          childAllocationAmounts: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects incoming allocations for an expense category', () {
      expect(
        () => calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: [
            AssetAmount.incoming(assetId: chf, amount: Decimal.parse('100')),
          ],
          childAllocationAmounts: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects outgoing allocations for an income category', () {
      expect(
        () => calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.income,
          valuationCurrencyId: chf,
          directAllocationAmounts: [
            AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('100')),
          ],
          childAllocationAmounts: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
