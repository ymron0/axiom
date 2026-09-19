@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotSubject', () {
    test('creates an account subject with typed account identity', () {
      final accountId = AccountId.fromString('account-1');

      final subject = BalanceSnapshotSubject.account(accountId);

      expect(subject.accountId, accountId);
      expect(subject.custodianId, isNull);
      expect(subject.jarId, isNull);
      expect(subject.id, accountId);

      expect(subject.isAccount, isTrue);
      expect(subject.isCustodian, isFalse);
      expect(subject.isJar, isFalse);
    });

    test('creates a custodian subject with typed custodian identity', () {
      final custodianId = CustodianId.fromString('custodian-1');

      final subject = BalanceSnapshotSubject.custodian(custodianId);

      expect(subject.accountId, isNull);
      expect(subject.custodianId, custodianId);
      expect(subject.jarId, isNull);
      expect(subject.id, custodianId);

      expect(subject.isAccount, isFalse);
      expect(subject.isCustodian, isTrue);
      expect(subject.isJar, isFalse);
    });

    test('creates a jar subject with typed jar identity', () {
      final jarId = JarId.fromString('jar-1');

      final subject = BalanceSnapshotSubject.jar(jarId);

      expect(subject.accountId, isNull);
      expect(subject.custodianId, isNull);
      expect(subject.jarId, jarId);
      expect(subject.id, jarId);

      expect(subject.isAccount, isFalse);
      expect(subject.isCustodian, isFalse);
      expect(subject.isJar, isTrue);
    });

    test('rejects a subject without an identity', () {
      expect(() => BalanceSnapshotSubject(), throwsA(isA<ArgumentError>()));
    });

    test('rejects account and custodian identities together', () {
      expect(
        () => BalanceSnapshotSubject(
          accountId: AccountId.fromString('account-1'),
          custodianId: CustodianId.fromString('custodian-1'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects account and jar identities together', () {
      expect(
        () => BalanceSnapshotSubject(
          accountId: AccountId.fromString('account-1'),
          jarId: JarId.fromString('jar-1'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects custodian and jar identities together', () {
      expect(
        () => BalanceSnapshotSubject(
          custodianId: CustodianId.fromString('custodian-1'),
          jarId: JarId.fromString('jar-1'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects all subject identities together', () {
      expect(
        () => BalanceSnapshotSubject(
          accountId: AccountId.fromString('account-1'),
          custodianId: CustodianId.fromString('custodian-1'),
          jarId: JarId.fromString('jar-1'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compares equivalent account subjects by mapped values', () {
      final first = BalanceSnapshotSubject.account(
        AccountId.fromString('account-1'),
      );

      final equivalent = BalanceSnapshotSubject.account(
        AccountId.fromString('account-1'),
      );

      final different = BalanceSnapshotSubject.account(
        AccountId.fromString('account-2'),
      );

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });

    test('distinguishes subjects belonging to different subject types', () {
      final account = BalanceSnapshotSubject.account(
        AccountId.fromString('same-value'),
      );

      final custodian = BalanceSnapshotSubject.custodian(
        CustodianId.fromString('same-value'),
      );

      final jar = BalanceSnapshotSubject.jar(JarId.fromString('same-value'));

      expect(account, isNot(custodian));
      expect(account, isNot(jar));
      expect(custodian, isNot(jar));
    });

    test('round-trips an account subject through mapping', () {
      final subject = BalanceSnapshotSubject.account(
        AccountId.fromString('account-1'),
      );

      final restored = BalanceSnapshotSubjectMapper.fromMap(subject.toMap());

      expect(restored, subject);
    });

    test('round-trips a custodian subject through mapping', () {
      final subject = BalanceSnapshotSubject.custodian(
        CustodianId.fromString('custodian-1'),
      );

      final restored = BalanceSnapshotSubjectMapper.fromMap(subject.toMap());

      expect(restored, subject);
    });

    test('round-trips a jar subject through mapping', () {
      final subject = BalanceSnapshotSubject.jar(JarId.fromString('jar-1'));

      final restored = BalanceSnapshotSubjectMapper.fromMap(subject.toMap());

      expect(restored, subject);
    });
  });
}
