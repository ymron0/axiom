@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('FeeExpression', () {
    final assetId = AssetId.fromString('asset-chf');

    group('PercentageFeeExpression', () {
      test('accepts a positive percentage', () {
        final expression = PercentageFeeExpression(
          percentage: Decimal.parse('1.25'),
        );

        expect(expression.percentage, Decimal.parse('1.25'));
      });

      test('rejects zero', () {
        expect(
          () => PercentageFeeExpression(percentage: Decimal.zero),
          throwsArgumentError,
        );
      });

      test('rejects a negative percentage', () {
        expect(
          () => PercentageFeeExpression(percentage: Decimal.parse('-0.1')),
          throwsArgumentError,
        );
      });

      test('round-trips through dart_mappable', () {
        final expression = PercentageFeeExpression(
          percentage: Decimal.parse('1.25'),
        );

        final restored = FeeExpressionMapper.fromMap(expression.toMap());

        expect(restored, expression);
        expect(restored, isA<PercentageFeeExpression>());
      });
    });

    group('AssetAmountFeeExpression', () {
      test('accepts an outgoing asset amount', () {
        final amount = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('5.00'),
        );

        final expression = AssetAmountFeeExpression(amount: amount);

        expect(expression.amount, amount);
      });

      test('rejects an incoming asset amount', () {
        final amount = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('5.00'),
        );

        expect(
          () => AssetAmountFeeExpression(amount: amount),
          throwsArgumentError,
        );
      });

      test('round-trips through dart_mappable', () {
        final expression = AssetAmountFeeExpression(
          amount: AssetAmount.outgoing(
            assetId: assetId,
            amount: Decimal.parse('5.00'),
          ),
        );

        final restored = FeeExpressionMapper.fromMap(expression.toMap());

        expect(restored, expression);
        expect(restored, isA<AssetAmountFeeExpression>());
      });
    });
  });
}
