@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_spending.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CategorySpending', () {
    final categoryId = CategoryId.fromString('groceries');
    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    test('accepts valid expense totals', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        directTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('100'),
        ),
        aggregateTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('150'),
        ),
      );

      expect(spending.categoryId, categoryId);
      expect(spending.kind, CategoryKind.expense);
      expect(spending.directTotal.amount, Decimal.parse('100'));
      expect(spending.aggregateTotal.amount, Decimal.parse('150'));
      expect(spending.valuationCurrencyId, chf);
    });

    test('accepts valid income totals', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.income,
        directTotal: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('1000'),
        ),
        aggregateTotal: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('1000'),
        ),
      );

      expect(spending.directTotal.isIncoming, isTrue);
      expect(spending.aggregateTotal.isIncoming, isTrue);
    });

    test('rejects totals using different assets', () {
      expect(
        () => CategorySpending(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          directTotal: AssetAmount.outgoing(
            assetId: chf,
            amount: Decimal.parse('100'),
          ),
          aggregateTotal: AssetAmount.outgoing(
            assetId: eur,
            amount: Decimal.parse('150'),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown direct total', () {
      expect(
        () => CategorySpending(
          categoryId: categoryId,
          kind: CategoryKind.expense,
          directTotal: AssetAmount.outgoing(
            assetId: chf,
            amount: Decimal.fromInt(-1),
          ),
          aggregateTotal: AssetAmount.outgoing(
            assetId: chf,
            amount: Decimal.parse('100'),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a net-negative expense category', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        directTotal: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('50'),
        ),
        aggregateTotal: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('75'),
        ),
      );

      expect(spending.directTotal.isIncoming, isTrue);
      expect(spending.directSignedValue, Decimal.parse('-50'));
      expect(spending.aggregateSignedValue, Decimal.parse('-75'));
    });

    test('accepts a net-negative income category', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.income,
        directTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('50'),
        ),
        aggregateTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('75'),
        ),
      );

      expect(spending.directTotal.isOutgoing, isTrue);
      expect(spending.directSignedValue, Decimal.parse('-50'));
      expect(spending.aggregateSignedValue, Decimal.parse('-75'));
    });

    test('accepts an aggregate total smaller than the direct magnitude', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        directTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('150'),
        ),
        aggregateTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('100'),
        ),
      );

      expect(spending.directSignedValue, Decimal.parse('150'));
      expect(spending.aggregateSignedValue, Decimal.parse('100'));
    });

    test('accepts an aggregate total with the opposite net direction', () {
      final spending = CategorySpending(
        categoryId: categoryId,
        kind: CategoryKind.expense,
        directTotal: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('100'),
        ),
        aggregateTotal: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('50'),
        ),
      );

      expect(spending.directSignedValue, Decimal.parse('100'));
      expect(spending.aggregateSignedValue, Decimal.parse('-50'));
    });
  });
}
