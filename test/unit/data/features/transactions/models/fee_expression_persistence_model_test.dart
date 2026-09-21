@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/models/fee_expression_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('FeeExpressionPersistenceModel', () {
    test('round-trips a percentage expression', () {
      final expression = PercentageFeeExpression(
        percentage: Decimal.parse('1.25'),
      );

      final model = FeeExpressionPersistenceModel.fromEntity(expression);

      final restored = FeeExpressionPersistenceModel.fromRecord(
        model.toRecord(),
        path: 'feeExpression',
      ).toEntity();

      expect(restored, expression);
      expect(restored, isA<PercentageFeeExpression>());
    });

    test('round-trips an asset-amount expression', () {
      final expression = AssetAmountFeeExpression(
        amount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-btc'),
          amount: Decimal.parse('0.0001'),
        ),
      );

      final model = FeeExpressionPersistenceModel.fromEntity(expression);

      final restored = FeeExpressionPersistenceModel.fromRecord(
        model.toRecord(),
        path: 'feeExpression',
      ).toEntity();

      expect(restored, expression);
      expect(restored, isA<AssetAmountFeeExpression>());
    });

    test('rejects an unsupported expression type', () {
      expect(
        () => FeeExpressionPersistenceModel.fromRecord(<String, Object?>{
          'type': 'unknown',
        }, path: 'feeExpression'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects malformed percentage data', () {
      expect(
        () => FeeExpressionPersistenceModel.fromRecord(<String, Object?>{
          'type': 'percentage',
          'percentage': 'invalid',
        }, path: 'feeExpression'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects malformed asset-amount data', () {
      expect(
        () => FeeExpressionPersistenceModel.fromRecord(<String, Object?>{
          'type': 'assetAmount',
          'amount': 'invalid',
        }, path: 'feeExpression'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
