@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/rates/data/models/rate_persistence_model.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../domain/features/rates/entities/rate_test.dart' show TestRate;

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

    test('rejects a rate subtype without persistence support', () {
      expect(
        () => RatePersistenceModel.fromEntity(
          TestRate(
            id: RateId.fromString('rate-1'),
            baseAssetId: AssetId.fromString('asset-eur'),
            quoteAssetId: AssetId.fromString('asset-usd'),
            rate: Decimal.one,
            effectiveAt: DateTime.utc(2026, 1, 1),
            entityVersion: 1,
            createdAt: DateTime.utc(2026, 1, 1),
            modifiedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects invalid decimal and type values during domain reconstruction', () {
      final record = RatePersistenceModel.fromEntity(exchangeRateFixture()).toRecord();
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
    });

    test('rejects timestamps without a timezone while reading the record', () {
      final record = RatePersistenceModel.fromEntity(exchangeRateFixture()).toRecord();

      expect(
        () => RatePersistenceModel.fromRecord(
          recordKey: 'rate-1',
          record: <String, Object?>{...record, 'effectiveAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('converts invalid reconstructed rate state to a persistence exception', () {
      final record = RatePersistenceModel.fromEntity(exchangeRateFixture()).toRecord();
      final model = RatePersistenceModel.fromRecord(recordKey: '', record: record);

      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });
  });
}
