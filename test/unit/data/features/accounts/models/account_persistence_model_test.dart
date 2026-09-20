@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/accounts/data/models/account_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';

void main() {
  group('AccountPersistenceModel', () {
    test('round-trips an active account', () {
      final account = accountFixture(id: 'account-1');
      final model = AccountPersistenceModel.fromEntity(account);

      expect(
        AccountPersistenceModel.fromRecord(
          recordKey: account.id.value,
          record: model.toRecord(),
        ).toEntity(),
        account,
      );
    });

    test('round-trips a complete logo', () {
      final account = accountFixture(
        id: 'account-1',
        logo: EntityLogo.remote('https://logo.test/account'),
      );

      final model = AccountPersistenceModel.fromEntity(account);

      expect(
        AccountPersistenceModel.fromRecord(
          recordKey: account.id.value,
          record: model.toRecord(),
        ).toEntity(),
        account,
      );
    });

    test('rejects deleted entities and corrupt persisted records', () {
      expect(
        () => AccountPersistenceModel.fromEntity(
          accountFixture(id: 'account-1', deletedAt: DateTime.utc(2026)),
        ),
        throwsStateError,
      );
      final record = AccountPersistenceModel.fromEntity(
        accountFixture(id: 'account-1'),
      ).toRecord();
      expect(
        () => AccountPersistenceModel.fromRecord(
          recordKey: 'account-1',
          record: <String, Object?>{...record, 'kind': 'invalid'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final deleted = AccountPersistenceModel.fromRecord(
        recordKey: 'account-1',
        record: <String, Object?>{
          ...record,
          'deletedAt': '2026-01-01T00:00:00.000Z',
        },
      );
      expect(deleted.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('translates invalid account invariants and logos', () {
      final record = AccountPersistenceModel.fromEntity(
        accountFixture(id: 'account-1'),
      ).toRecord();

      final invalidAccount = AccountPersistenceModel.fromRecord(
        recordKey: 'account-1',
        record: <String, Object?>{...record, 'name': ''},
      );
      expect(
        invalidAccount.toEntity,
        throwsA(isA<PersistenceRecordException>()),
      );

      final invalidLogo = AccountPersistenceModel.fromRecord(
        recordKey: 'account-1',
        record: <String, Object?>{
          ...record,
          'logo': <String, Object?>{'source': 'remote', 'value': ''},
        },
      );
      expect(invalidLogo.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('rejects malformed and timezone-less timestamps', () {
      final record = AccountPersistenceModel.fromEntity(
        accountFixture(id: 'account-1'),
      ).toRecord();

      expect(
        () => AccountPersistenceModel.fromRecord(
          recordKey: 'account-1',
          record: <String, Object?>{...record, 'createdAt': 'not-a-date'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => AccountPersistenceModel.fromRecord(
          recordKey: 'account-1',
          record: <String, Object?>{...record, 'archivedAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
