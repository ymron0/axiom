@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/rates/data/models/rate_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  group('RatePersistenceModel', () {
    test('round-trips an exchange rate', () {
      final rate = exchangeRateFixture();
      final model = RatePersistenceModel.fromEntity(rate);
      final rebuilt = RatePersistenceModel.fromRecord(
        recordKey: rate.id.value,
        record: model.toRecord(),
      );

      expect(rebuilt.toEntity(), rate);
    });

    test('round-trips a market-price rate', () {
      final rate = marketPriceRateFixture();
      final model = RatePersistenceModel.fromEntity(rate);
      final rebuilt = RatePersistenceModel.fromRecord(
        recordKey: rate.id.value,
        record: model.toRecord(),
      );

      expect(rebuilt.toEntity(), rate);
    });

    test(
      'rejects invalid decimal and type values during domain reconstruction',
      () {
        final record = RatePersistenceModel.fromEntity(
          exchangeRateFixture(),
        ).toRecord();
        for (final override in <String, Object?>{
          'rate': 'invalid',
          'type': 'unsupported',
        }.entries) {
          final model = RatePersistenceModel.fromRecord(
            recordKey: 'rate-1',
            record: <String, Object?>{...record, override.key: override.value},
          );
          expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
        }
      },
    );

    test('rejects timestamps without a timezone while reading the record', () {
      final record = RatePersistenceModel.fromEntity(
        exchangeRateFixture(),
      ).toRecord();

      expect(
        () => RatePersistenceModel.fromRecord(
          recordKey: 'rate-1',
          record: <String, Object?>{...record, 'effectiveAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test(
      'converts invalid reconstructed rate state to a persistence exception',
      () {
        final record = RatePersistenceModel.fromEntity(
          exchangeRateFixture(),
        ).toRecord();
        final model = RatePersistenceModel.fromRecord(
          recordKey: '',
          record: record,
        );

        expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
      },
    );
  });
}
