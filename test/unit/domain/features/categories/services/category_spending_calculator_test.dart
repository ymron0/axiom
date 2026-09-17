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

    test('nets incoming reimbursements against an expense category', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('200')),
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('75')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('125'));
      expect(result.directTotal.isOutgoing, isTrue);
      expect(result.directSignedValue, Decimal.parse('125'));

      expect(result.aggregateTotal.amount, Decimal.parse('125'));
      expect(result.aggregateTotal.isOutgoing, isTrue);
      expect(result.aggregateSignedValue, Decimal.parse('125'));
    });

    test('allows an expense category to become negative when reimbursements '
        'exceed expenses', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('200')),
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('350')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('150'));
      expect(result.directTotal.isIncoming, isTrue);
      expect(result.directSignedValue, Decimal.parse('-150'));

      expect(result.aggregateTotal.amount, Decimal.parse('150'));
      expect(result.aggregateTotal.isIncoming, isTrue);
      expect(result.aggregateSignedValue, Decimal.parse('-150'));
    });

    test('nets outgoing adjustments against an income category', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.income,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('1000')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('250')),
        ],
        childAllocationAmounts: const [],
      );

      expect(result.directTotal.amount, Decimal.parse('750'));
      expect(result.directTotal.isIncoming, isTrue);
      expect(result.directSignedValue, Decimal.parse('750'));
    });

    test(
      'allows an income category to become negative when outgoing adjustments '
      'exceed income',
      () {
        final result = calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.income,
          valuationCurrencyId: chf,
          directAllocationAmounts: [
            AssetAmount.incoming(assetId: chf, amount: Decimal.parse('100')),
            AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('150')),
          ],
          childAllocationAmounts: const [],
        );

        expect(result.directTotal.amount, Decimal.parse('50'));
        expect(result.directTotal.isOutgoing, isTrue);
        expect(result.directSignedValue, Decimal.parse('-50'));
      },
    );

    test('child activity can reduce and reverse the aggregate total', () {
      final result = calculator.calculate(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        valuationCurrencyId: chf,
        directAllocationAmounts: [
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('100')),
        ],
        childAllocationAmounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('150')),
        ],
      );

      expect(result.directTotal.amount, Decimal.parse('100'));
      expect(result.directTotal.isOutgoing, isTrue);
      expect(result.directSignedValue, Decimal.parse('100'));

      expect(result.aggregateTotal.amount, Decimal.parse('50'));
      expect(result.aggregateTotal.isIncoming, isTrue);
      expect(result.aggregateSignedValue, Decimal.parse('-50'));
    });

    test(
      'mixed allocations produce deterministic zero regardless of order',
      () {
        final outgoing = AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('100'),
        );
        final incoming = AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('100'),
        );

        final forward = calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: [outgoing, incoming],
          childAllocationAmounts: const [],
        );

        final reversed = calculator.calculate(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          valuationCurrencyId: chf,
          directAllocationAmounts: [incoming, outgoing],
          childAllocationAmounts: const [],
        );

        expect(forward.directTotal.amount, Decimal.zero);
        expect(forward.directTotal.isOutgoing, isTrue);
        expect(forward.directSignedValue, Decimal.zero);

        expect(reversed.directTotal.amount, Decimal.zero);
        expect(reversed.directTotal.isOutgoing, isTrue);
        expect(reversed.directSignedValue, Decimal.zero);
      },
    );
  });
}
