@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/merchants/data/models/merchant_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';

void main() {
  group('MerchantPersistenceModel', () {
    test('round-trips a merchant including nullable lifecycle values', () {
      final merchant = merchantFixture(id: 'merchant-1');
      final model = MerchantPersistenceModel.fromEntity(merchant);

      expect(
        MerchantPersistenceModel.fromRecord(
          recordKey: merchant.id.value,
          record: model.toRecord(),
        ).toEntity(),
        merchant,
      );
    });

    test('rejects malformed timestamps and domain-invalid records', () {
      final record = MerchantPersistenceModel.fromEntity(
        merchantFixture(id: 'merchant-1'),
      ).toRecord();
      expect(
        () => MerchantPersistenceModel.fromRecord(
          recordKey: 'merchant-1',
          record: <String, Object?>{...record, 'createdAt': 'not-a-date'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final invalid = MerchantPersistenceModel.fromRecord(
        recordKey: '',
        record: record,
      );
      expect(invalid.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('rejects non-UTC optional timestamps', () {
      final record = MerchantPersistenceModel.fromEntity(
        merchantFixture(id: 'merchant-1'),
      ).toRecord();

      expect(
        () => MerchantPersistenceModel.fromRecord(
          recordKey: 'merchant-1',
          record: <String, Object?>{
            ...record,
            'deletedAt': '2026-01-01T00:00:00',
          },
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (exception) => exception.field,
            'field',
            'deletedAt',
          ),
        ),
      );
    });
  });
}
