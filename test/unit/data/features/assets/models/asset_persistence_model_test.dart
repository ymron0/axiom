@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/data/models/asset_persistence_model.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('AssetPersistenceModel', () {
    test('round-trips a currency', () {
      final original = currencyFixture(id: 'asset-eur');
      final model = AssetPersistenceModel.fromEntity(original);
      final rebuilt = AssetPersistenceModel.fromRecord(
        recordKey: original.id.value,
        record: model.toRecord(),
      );

      expect(rebuilt.toEntity(), original);
    });

    test('round-trips complete logo data', () {
      final original = Currency(
        id: AssetId.fromString('asset-eur'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Euro',
        code: AssetCode('EUR'),
        decimalPlaces: 2,
        logo: EntityLogo(
          source: EntityLogoSource.remote,
          value: 'https://logo.test/euro',
        ),
      );
      final model = AssetPersistenceModel.fromEntity(original);
      final rebuilt = AssetPersistenceModel.fromRecord(
        recordKey: original.id.value,
        record: model.toRecord(),
      );

      expect(rebuilt.toRecord()['logo'], <String, Object?>{
        'source': 'remote',
        'value': 'https://logo.test/euro',
      });
      expect(rebuilt.toEntity(), original);
    });

    test('rejects malformed timestamp and logo source records', () {
      final record = AssetPersistenceModel.fromEntity(
        currencyFixture(),
      ).toRecord();

      expect(
        () => AssetPersistenceModel.fromRecord(
          recordKey: 'asset-1',
          record: <String, Object?>{...record, 'createdAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => AssetPersistenceModel.fromRecord(
          recordKey: 'asset-1',
          record: <String, Object?>{
            ...record,
            'logo': <String, Object?>{'source': 'unknown', 'value': 'logo'},
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects unsupported asset types during domain reconstruction', () {
      final record = AssetPersistenceModel.fromEntity(
        currencyFixture(),
      ).toRecord();
      final model = AssetPersistenceModel.fromRecord(
        recordKey: 'asset-1',
        record: <String, Object?>{...record, 'type': 'crypto'},
      );

      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test(
      'converts invalid reconstructed asset state to a persistence exception',
      () {
        final record = AssetPersistenceModel.fromEntity(
          currencyFixture(),
        ).toRecord();
        final model = AssetPersistenceModel.fromRecord(
          recordKey: '',
          record: record,
        );

        expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
      },
    );
  });
}
