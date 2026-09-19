@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_record_key.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotRecordKey', () {
    final date = CalendarDate(2026, 9, 19);

    test('creates account key', () {
      final key = BalanceSnapshotRecordKey.fromSubject(
        subject: BalanceSnapshotSubject.account(
          AccountId.fromString('account-1'),
        ),
        snapshotDate: date,
      );

      expect(key.subjectType, 'account');
      expect(key.subjectId, 'account-1');
      expect(key.subjectKey, 'account|account-1');
      expect(key.value, 'account|account-1|2026-09-19');
    });

    test('creates custodian key', () {
      final key = BalanceSnapshotRecordKey.fromSubject(
        subject: BalanceSnapshotSubject.custodian(
          CustodianId.fromString('custodian-1'),
        ),
        snapshotDate: date,
      );

      expect(key.subjectType, 'custodian');
      expect(key.subjectId, 'custodian-1');
      expect(key.subjectKey, 'custodian|custodian-1');
      expect(key.value, 'custodian|custodian-1|2026-09-19');
    });

    test('creates jar key', () {
      final key = BalanceSnapshotRecordKey.fromSubject(
        subject: BalanceSnapshotSubject.jar(JarId.fromString('jar-1')),
        snapshotDate: date,
      );

      expect(key.subjectType, 'jar');
      expect(key.subjectId, 'jar-1');
      expect(key.subjectKey, 'jar|jar-1');
      expect(key.value, 'jar|jar-1|2026-09-19');
    });

    test('encodes subject identifiers containing key separators', () {
      final key = BalanceSnapshotRecordKey.fromSubject(
        subject: BalanceSnapshotSubject.account(
          AccountId.fromString('broker|account/1'),
        ),
        snapshotDate: date,
      );

      expect(key.value, 'account|broker%7Caccount%2F1|2026-09-19');

      final restored = BalanceSnapshotRecordKey.parse(key.value);

      expect(restored.subjectId, 'broker|account/1');

      expect(restored.value, key.value);
    });

    test('parses account key into typed subject', () {
      final key = BalanceSnapshotRecordKey.parse(
        'account|account-1|2026-09-19',
      );

      final subject = key.toSubject();

      expect(subject.accountId, AccountId.fromString('account-1'));

      expect(subject.isAccount, isTrue);
    });

    test('parses custodian key into typed subject', () {
      final key = BalanceSnapshotRecordKey.parse(
        'custodian|custodian-1|2026-09-19',
      );

      final subject = key.toSubject();

      expect(subject.custodianId, CustodianId.fromString('custodian-1'));

      expect(subject.isCustodian, isTrue);
    });

    test('parses jar key into typed subject', () {
      final key = BalanceSnapshotRecordKey.parse('jar|jar-1|2026-09-19');

      final subject = key.toSubject();

      expect(subject.jarId, JarId.fromString('jar-1'));

      expect(subject.isJar, isTrue);
    });

    test('rejects malformed number of key components', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('account|account-1'),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            'recordKey',
          ),
        ),
      );
    });

    test('rejects unsupported subject type', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('category|category-1|2026-09-19'),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            'recordKey',
          ),
        ),
      );
    });

    test('rejects blank decoded subject identity', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('account||2026-09-19'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid encoded subject identity', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('account|%ZZ|2026-09-19'),
        throwsA(
          isA<PersistenceRecordException>()
              .having((error) => error.field, 'field', 'recordKey')
              .having(
                (error) => error.reason,
                'reason',
                'Snapshot record key contains an invalid encoded subject ID.',
              ),
        ),
      );
    });

    test('rejects malformed snapshot date', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('account|account-1|not-a-date'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid snapshot date', () {
      expect(
        () => BalanceSnapshotRecordKey.parse('account|account-1|2026-02-31'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('fromParts rejects unsupported subject type', () {
      expect(
        () => BalanceSnapshotRecordKey.fromParts(
          subjectType: 'budget',
          subjectId: 'budget-1',
          snapshotDate: date,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('fromParts rejects blank subject identity', () {
      expect(
        () => BalanceSnapshotRecordKey.fromParts(
          subjectType: BalanceSnapshotRecordKey.accountType,
          subjectId: '   ',
          snapshotDate: date,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
