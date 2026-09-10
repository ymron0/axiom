import 'dart:convert';

import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/budget_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSplit', () {
    final transactionAmount = AssetAmount.outgoing(
      assetId: AssetId.fromString('transaction-asset'),
      amount: Decimal.parse('12.50'),
    );
    final valuationAmount = AssetAmount.outgoing(
      assetId: AssetId.fromString('valuation-asset'),
      amount: Decimal.parse('10.00'),
    );
    final budgetId = BudgetId.fromString('budget-123');
    final categoryId = CategoryId.fromString('category-123');
    final jarId = JarId.fromString('jar-123');

    test('accepts each allocation target independently', () {
      // Given
      final splits = [
        TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
          budgetId: budgetId,
        ),
        TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
          categoryId: categoryId,
        ),
        TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
          jarId: jarId,
        ),
      ];

      // Then
      expect(splits[0].transactionAmount, same(transactionAmount));
      expect(splits[0].valuationAmount, same(valuationAmount));
      expect(splits[0].budgetId, same(budgetId));
      expect(splits[0].categoryId, isNull);
      expect(splits[0].jarId, isNull);
      expect(splits[1].transactionAmount, same(transactionAmount));
      expect(splits[1].valuationAmount, same(valuationAmount));
      expect(splits[1].budgetId, isNull);
      expect(splits[1].categoryId, same(categoryId));
      expect(splits[1].jarId, isNull);
      expect(splits[2].transactionAmount, same(transactionAmount));
      expect(splits[2].valuationAmount, same(valuationAmount));
      expect(splits[2].budgetId, isNull);
      expect(splits[2].categoryId, isNull);
      expect(splits[2].jarId, same(jarId));
    });

    test('accepts multiple allocation targets without multiplying amount', () {
      // When
      final split = TransactionSplit(
        transactionAmount: transactionAmount,
        valuationAmount: valuationAmount,
        budgetId: budgetId,
        categoryId: categoryId,
        jarId: jarId,
      );

      // Then
      expect(split.transactionAmount, same(transactionAmount));
      expect(split.valuationAmount, same(valuationAmount));
      expect(split.budgetId, same(budgetId));
      expect(split.categoryId, same(categoryId));
      expect(split.jarId, same(jarId));
    });

    test('rejects a split without an allocation target', () {
      // When / Then
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'A transaction split must specify at least one allocation target.',
          ),
        ),
      );
    });

    test('rejects amounts with different directions', () {
      // When / Then
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: AssetAmount.incoming(
            assetId: AssetId.fromString('valuation-asset'),
            amount: Decimal.parse('10.00'),
          ),
          budgetId: budgetId,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Valuation amount must have the same direction as the transaction '
                'amount.',
          ),
        ),
      );
    });

    test('rejects different quantities when amounts use the same asset', () {
      // When / Then
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: AssetAmount.outgoing(
            assetId: transactionAmount.assetId,
            amount: Decimal.parse('10.00'),
          ),
          budgetId: budgetId,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Transaction and valuation amounts must be equal when they use the '
                'same asset.',
          ),
        ),
      );
    });

    test('accepts equal quantities when amounts use the same asset', () {
      // Given
      final sameAsset = AssetId.fromString('shared-asset');
      final transactionAmount = AssetAmount.outgoing(
        assetId: sameAsset,
        amount: Decimal.parse('12.50'),
      );
      final valuationAmount = AssetAmount.outgoing(
        assetId: sameAsset,
        amount: Decimal.parse('12.50'),
      );

      // When
      final split = TransactionSplit(
        transactionAmount: transactionAmount,
        valuationAmount: valuationAmount,
        budgetId: budgetId,
      );

      // Then
      expect(split.transactionAmount, same(transactionAmount));
      expect(split.valuationAmount, same(valuationAmount));
    });

    test('compares equal when all value fields are equal', () {
      // Given
      final first = TransactionSplit(
        transactionAmount: transactionAmount,
        valuationAmount: valuationAmount,
        budgetId: budgetId,
        categoryId: categoryId,
      );
      final same = TransactionSplit(
        transactionAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('transaction-asset'),
          amount: Decimal.parse('12.50'),
        ),
        valuationAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('valuation-asset'),
          amount: Decimal.parse('10.00'),
        ),
        budgetId: BudgetId.fromString('budget-123'),
        categoryId: CategoryId.fromString('category-123'),
      );

      // Then
      expect(first, same);
    });

    test('round trips through dart_mappable serialization', () {
      // Given
      final split = TransactionSplit(
        transactionAmount: transactionAmount,
        valuationAmount: valuationAmount,
        budgetId: budgetId,
        categoryId: categoryId,
        jarId: jarId,
      );

      // When
      final decoded = TransactionSplitMapper.fromJson(split.toJson());

      // Then
      expect(decoded, split);
    });

    test('rejects invalid data during dart_mappable deserialization', () {
      // Given
      final encoded =
          jsonDecode(
                TransactionSplit(
                  transactionAmount: transactionAmount,
                  valuationAmount: valuationAmount,
                  budgetId: budgetId,
                ).toJson(),
              )
              as Map<String, dynamic>;
      encoded.remove('budgetId');

      // When / Then
      expect(
        () => TransactionSplitMapper.fromJson(jsonEncode(encoded)),
        throwsA(
          isA<MapperException>().having(
            (error) => error.message,
            'message',
            'Failed to decode (TransactionSplit): Invalid argument(s): '
                'A transaction split must specify at least one allocation '
                'target.',
          ),
        ),
      );
    });
  });
}
