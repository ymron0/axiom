@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AssetAmountPersistenceModel', () {
    const record = <String, Object?>{
      'assetId': 'asset-1',
      'amount': '12.50',
      'direction': 'outgoing',
    };

    test('round-trips the persistence representation and domain value', () {
      final model = AssetAmountPersistenceModel.fromRecord(record, path: 'amount');

      expect(model.toRecord(), <String, Object?>{
        ...record,
        'amount': '12.5',
      });
      expect(model.toEntity().amount, Decimal.parse('12.50'));
    });

    test('reports malformed structural values with their nested path', () {
      expect(
        () => AssetAmountPersistenceModel.fromRecord(
          <String, Object?>{...record, 'amount': 'invalid'},
          path: 'entry.amount',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('preserves domain identifier errors when rebuilding an amount', () {
      final model = AssetAmountPersistenceModel(
        assetId: '',
        amount: Decimal.one,
        direction: AssetAmountDirection.incoming,
      );

      expect(model.toEntity, throwsArgumentError);
    });
  });
}
