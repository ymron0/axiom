@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/jars/data/models/jar_target_amount_persistence_model.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarTargetAmountPersistenceModel', () {
    const record = <String, Object?>{
      'assetId': 'asset-1',
      'direction': 'incoming',
      'value': '42.25',
    };

    test('round-trips a target amount', () {
      final model = JarTargetAmountPersistenceModel.fromRecord(record);

      expect(model.toRecord(), record);
      expect(model.toEntity().amount, Decimal.parse('42.25'));
    });

    test('reports malformed serialized values and invalid identifiers', () {
      expect(
        () => JarTargetAmountPersistenceModel.fromRecord(
          <String, Object?>{...record, 'direction': 'sideways'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final model = JarTargetAmountPersistenceModel.fromRecord(
        <String, Object?>{...record, 'assetId': ''},
      );
      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });
  });
}
