@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/features/custodians/data/models/custodian_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';

void main() {
  group('CustodianPersistenceModel', () {
    test('round-trips an active custodian', () {
      final custodian = custodianFixture(id: 'custodian-1');
      final model = CustodianPersistenceModel.fromEntity(custodian);

      expect(
        CustodianPersistenceModel.fromRecord(
          recordKey: custodian.id.value,
          record: model.toRecord(),
        ).toEntity(),
        custodian,
      );
    });

    test('rejects deleted entities and invalid persisted enum values', () {
      expect(
        () => CustodianPersistenceModel.fromEntity(
          custodianFixture(id: 'custodian-1', deletedAt: DateTime.utc(2026)),
        ),
        throwsStateError,
      );
      final record = CustodianPersistenceModel.fromEntity(
        custodianFixture(id: 'custodian-1'),
      ).toRecord();
      expect(
        () => CustodianPersistenceModel.fromRecord(
          recordKey: 'custodian-1',
          record: <String, Object?>{...record, 'icon': 'invalid'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final deleted = CustodianPersistenceModel.fromRecord(
        recordKey: 'custodian-1',
        record: <String, Object?>{
          ...record,
          'deletedAt': '2026-01-01T00:00:00.000Z',
        },
      );
      expect(deleted.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('round-trips a persisted logo', () {
      final custodian = custodianFixture(
        id: 'custodian-logo',
        logo: EntityLogo.asset('assets/custodian.png'),
      );
      final model = CustodianPersistenceModel.fromEntity(custodian);

      expect(
        CustodianPersistenceModel.fromRecord(
          recordKey: custodian.id.value,
          record: model.toRecord(),
        ).toEntity(),
        custodian,
      );
    });

    test('rejects incomplete and invalid persisted logos', () {
      final record = CustodianPersistenceModel.fromEntity(
        custodianFixture(id: 'custodian-1'),
      ).toRecord();
      expect(
        () => CustodianPersistenceModel.fromRecord(
          recordKey: 'custodian-1',
          record: <String, Object?>{
            ...record,
            'logo': <String, Object?>{'source': 'asset'},
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final invalidLogo = CustodianPersistenceModel.fromRecord(
        recordKey: 'custodian-1',
        record: <String, Object?>{
          ...record,
          'logo': <String, Object?>{
            'source': EntityLogoSource.asset.name,
            'value': '',
          },
        },
      );
      expect(
        invalidLogo.toEntity,
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('translates invalid persisted IDs and timestamps', () {
      final record = CustodianPersistenceModel.fromEntity(
        custodianFixture(id: 'custodian-1'),
      ).toRecord();
      final invalidId = CustodianPersistenceModel.fromRecord(
        recordKey: '',
        record: record,
      );
      expect(invalidId.toEntity, throwsA(isA<PersistenceRecordException>()));
      expect(
        () => CustodianPersistenceModel.fromRecord(
          recordKey: 'custodian-1',
          record: <String, Object?>{...record, 'createdAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
