@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_persistence_model.dart';
import 'package:axiom/src/features/balance_snapshots/data/repositories/sembast_balance_snapshot_repository_impl.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_persistence_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:decimal/decimal.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late BalanceSnapshotRepository repository;

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastBalanceSnapshotRepositoryImpl(database: database);
  });

  group('SembastBalanceSnapshotRepositoryImpl', () {
    group('save', () {
      test('persists a balance snapshot', () async {
        // Given
        final snapshot = _accountSnapshot(date: CalendarDate(2026, 9, 19));

        // When
        final result = await repository.save(snapshot);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getByDate(
          subject: snapshot.subject,
          snapshotDate: snapshot.snapshotDate,
        )).valueOrNull;

        expect(stored, snapshot);
      });

      test('is idempotent for the same natural key', () async {
        // Given
        final snapshot = _accountSnapshot(date: CalendarDate(2026, 9, 19));

        // When
        final firstResult = await repository.save(snapshot);
        final secondResult = await repository.save(snapshot);

        // Then
        expect(firstResult.isSuccess, isTrue);
        expect(secondResult.isSuccess, isTrue);

        expect(await SembastStores.balanceSnapshots.count(database), 1);

        expect(
          (await repository.getByDate(
            subject: snapshot.subject,
            snapshotDate: snapshot.snapshotDate,
          )).valueOrNull,
          snapshot,
        );
      });

      test(
        'replaces an existing snapshot using the same natural key',
        () async {
          // Given
          final date = CalendarDate(2026, 9, 19);

          final original = _accountSnapshot(
            date: date,
            capturedAt: DateTime.utc(2026, 9, 20, 1),
            assetAmount: '100',
            denominationAmount: '90',
            valuationAmount: '95',
          );

          final replacement = _accountSnapshot(
            date: date,
            capturedAt: DateTime.utc(2026, 9, 20, 4),
            assetAmount: '125',
            denominationAmount: '112',
            valuationAmount: '119',
          );

          await repository.save(original);

          // When
          final result = await repository.save(replacement);

          // Then
          expect(result.isSuccess, isTrue);

          expect(await SembastStores.balanceSnapshots.count(database), 1);

          final stored = (await repository.getByDate(
            subject: replacement.subject,
            snapshotDate: date,
          )).valueOrNull!;

          expect(stored, replacement);
          expect(stored.capturedAt, DateTime.utc(2026, 9, 20, 4));
          expect(stored.denominationAmount.amount, Decimal.parse('112'));
          expect(stored.valuationAmount.amount, Decimal.parse('119'));
        },
      );

      test(
        'keeps equal raw IDs from different subject types independent',
        () async {
          // Given
          const sharedId = 'shared-id';
          final date = CalendarDate(2026, 9, 19);

          final accountSnapshot = _accountSnapshot(
            accountId: sharedId,
            date: date,
          );

          final custodianSnapshot = _custodianSnapshot(
            custodianId: sharedId,
            date: date,
          );

          // When
          await repository.save(accountSnapshot);
          await repository.save(custodianSnapshot);

          // Then
          expect(await SembastStores.balanceSnapshots.count(database), 2);

          final storedAccount = (await repository.getByDate(
            subject: accountSnapshot.subject,
            snapshotDate: date,
          )).valueOrNull;

          final storedCustodian = (await repository.getByDate(
            subject: custodianSnapshot.subject,
            snapshotDate: date,
          )).valueOrNull;

          expect(storedAccount, accountSnapshot);
          expect(storedCustodian, custodianSnapshot);
        },
      );
    });

    group('getByDate', () {
      test('returns the exact requested date', () async {
        // Given
        final first = _accountSnapshot(date: CalendarDate(2026, 9, 18));

        final requested = _accountSnapshot(
          date: CalendarDate(2026, 9, 19),
          assetAmount: '200',
          denominationAmount: '180',
          valuationAmount: '190',
        );

        final third = _accountSnapshot(
          date: CalendarDate(2026, 9, 20),
          assetAmount: '300',
          denominationAmount: '270',
          valuationAmount: '285',
        );

        await repository.save(first);
        await repository.save(requested);
        await repository.save(third);

        // When
        final result = await repository.getByDate(
          subject: requested.subject,
          snapshotDate: CalendarDate(2026, 9, 19),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, requested);
      });

      test('returns successful null when the exact date is missing', () async {
        // Given
        final existing = _accountSnapshot(date: CalendarDate(2026, 9, 18));

        await repository.save(existing);

        // When
        final result = await repository.getByDate(
          subject: existing.subject,
          snapshotDate: CalendarDate(2026, 9, 19),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('does not substitute a neighbouring snapshot', () async {
        // Given
        final previous = _accountSnapshot(date: CalendarDate(2026, 9, 18));

        final next = _accountSnapshot(date: CalendarDate(2026, 9, 20));

        await repository.save(previous);
        await repository.save(next);

        // When
        final result = await repository.getByDate(
          subject: previous.subject,
          snapshotDate: CalendarDate(2026, 9, 19),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('getByDateRange', () {
      test('queries custodian and jar subjects by their typed keys', () async {
        // Given
        final date = CalendarDate(2026, 9, 19);
        final custodian = _custodianSnapshot(date: date);
        final jar = _jarSnapshot(date: date);
        final range = BalanceSnapshotDateRange(
          from: CalendarDate(2026, 9, 1),
          until: CalendarDate(2026, 10, 1),
        );

        await repository.save(custodian);
        await repository.save(jar);

        // When
        final custodianResult = await repository.getByDateRange(
          subject: custodian.subject,
          range: range,
        );
        final jarResult = await repository.getByDateRange(
          subject: jar.subject,
          range: range,
        );

        // Then
        expect(custodianResult.valueOrNull, [custodian]);
        expect(jarResult.valueOrNull, [jar]);
      });

      test('returns only requested subject ordered oldest to newest', () async {
        // Given
        final first = _accountSnapshot(
          date: CalendarDate(2026, 9, 1),
          assetAmount: '100',
        );

        final second = _accountSnapshot(
          date: CalendarDate(2026, 9, 2),
          assetAmount: '200',
        );

        final third = _accountSnapshot(
          date: CalendarDate(2026, 9, 3),
          assetAmount: '300',
        );

        final unrelated = _accountSnapshot(
          accountId: 'unrelated-account',
          date: CalendarDate(2026, 9, 2),
          assetAmount: '999',
        );

        // Deliberately save out of date order.
        await repository.save(third);
        await repository.save(unrelated);
        await repository.save(first);
        await repository.save(second);

        // When
        final result = await repository.getByDateRange(
          subject: first.subject,
          range: BalanceSnapshotDateRange(
            from: CalendarDate(2026, 9, 1),
            until: CalendarDate(2026, 9, 4),
          ),
        );

        // Then
        expect(result.isSuccess, isTrue);

        final snapshots = result.valueOrNull!;

        expect(snapshots.map((snapshot) => snapshot.snapshotDate), [
          CalendarDate(2026, 9, 1),
          CalendarDate(2026, 9, 2),
          CalendarDate(2026, 9, 3),
        ]);

        expect(
          snapshots.every((snapshot) => snapshot.subject == first.subject),
          isTrue,
        );

        expect(() => snapshots.clear(), throwsUnsupportedError);
      });

      test('uses inclusive from and exclusive until boundaries', () async {
        // Given
        final before = _accountSnapshot(date: CalendarDate(2026, 8, 31));

        final from = _accountSnapshot(
          date: CalendarDate(2026, 9, 1),
          assetAmount: '101',
        );

        final middle = _accountSnapshot(
          date: CalendarDate(2026, 9, 2),
          assetAmount: '102',
        );

        final until = _accountSnapshot(
          date: CalendarDate(2026, 9, 3),
          assetAmount: '103',
        );

        await repository.save(before);
        await repository.save(from);
        await repository.save(middle);
        await repository.save(until);

        // When
        final result = await repository.getByDateRange(
          subject: from.subject,
          range: BalanceSnapshotDateRange(
            from: CalendarDate(2026, 9, 1),
            until: CalendarDate(2026, 9, 3),
          ),
        );

        // Then
        expect(result.valueOrNull!.map((snapshot) => snapshot.snapshotDate), [
          CalendarDate(2026, 9, 1),
          CalendarDate(2026, 9, 2),
        ]);
      });

      test('returns immutable empty list when no snapshots match', () async {
        // Given
        final subject = BalanceSnapshotSubject.account(
          AccountId.fromString('missing-range'),
        );

        // When
        final result = await repository.getByDateRange(
          subject: subject,
          range: BalanceSnapshotDateRange(
            from: CalendarDate(2026, 9, 1),
            until: CalendarDate(2026, 10, 1),
          ),
        );

        // Then
        expect(result.isSuccess, isTrue);

        final snapshots = result.valueOrNull!;

        expect(snapshots, isEmpty);
        expect(() => snapshots.add(_accountSnapshot()), throwsUnsupportedError);
      });

      test('returns immutable empty list for an empty range', () async {
        // Given
        final snapshot = _accountSnapshot(date: CalendarDate(2026, 9, 19));

        await repository.save(snapshot);

        final date = CalendarDate(2026, 9, 19);

        // When
        final result = await repository.getByDateRange(
          subject: snapshot.subject,
          range: BalanceSnapshotDateRange(from: date, until: date),
        );

        // Then
        expect(result.isSuccess, isTrue);

        final snapshots = result.valueOrNull!;

        expect(snapshots, isEmpty);
        expect(() => snapshots.add(snapshot), throwsUnsupportedError);
      });
    });

    group('getLatest', () {
      test('returns snapshot with greatest snapshot date', () async {
        // Given
        final earlierDateButLaterCapture = _accountSnapshot(
          date: CalendarDate(2026, 9, 18),
          capturedAt: DateTime.utc(2026, 9, 25),
          assetAmount: '100',
        );

        final latestDateButEarlierCapture = _accountSnapshot(
          date: CalendarDate(2026, 9, 20),
          capturedAt: DateTime.utc(2026, 9, 21),
          assetAmount: '200',
        );

        final middle = _accountSnapshot(
          date: CalendarDate(2026, 9, 19),
          capturedAt: DateTime.utc(2026, 9, 30),
          assetAmount: '150',
        );

        await repository.save(middle);
        await repository.save(latestDateButEarlierCapture);
        await repository.save(earlierDateButLaterCapture);

        // When
        final result = await repository.getLatest(
          earlierDateButLaterCapture.subject,
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, latestDateButEarlierCapture);
        expect(result.valueOrNull!.snapshotDate, CalendarDate(2026, 9, 20));
      });

      test('returns successful null when subject has no snapshots', () async {
        // Given
        final subject = BalanceSnapshotSubject.account(
          AccountId.fromString('missing-latest'),
        );

        // When
        final result = await repository.getLatest(subject);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('does not return another subject latest snapshot', () async {
        // Given
        final existing = _accountSnapshot(
          accountId: 'existing',
          date: CalendarDate(2026, 9, 19),
        );

        await repository.save(existing);

        final missingSubject = BalanceSnapshotSubject.account(
          AccountId.fromString('another-account'),
        );

        // When
        final result = await repository.getLatest(missingSubject);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('corrupt persistence', () {
      test(
        'getByDate translates corrupt exact-date record to typed failure',
        () async {
          // Given
          final snapshot = _accountSnapshot(
            accountId: 'corrupt-exact',
            date: CalendarDate(2026, 9, 19),
          );

          final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

          await SembastStores.balanceSnapshots
              .record(model.recordKey)
              .put(database, <String, Object?>{});

          // When
          final result = await repository.getByDate(
            subject: snapshot.subject,
            snapshotDate: snapshot.snapshotDate,
          );

          // Then
          expect(
            result.failureOrNull,
            isA<BalanceSnapshotPersistenceFailure>(),
          );
        },
      );

      test(
        'range query translates matching corrupt record to typed failure',
        () async {
          // Given
          final snapshot = _accountSnapshot(
            accountId: 'corrupt-range',
            date: CalendarDate(2026, 9, 19),
          );

          final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

          final corruptRecord = <String, Object?>{
            ...model.toRecord(),
            BalanceSnapshotPersistenceModel.recordVersionField: 999,
          };

          await SembastStores.balanceSnapshots
              .record(model.recordKey)
              .put(database, corruptRecord);

          // When
          final result = await repository.getByDateRange(
            subject: snapshot.subject,
            range: BalanceSnapshotDateRange(
              from: CalendarDate(2026, 9, 1),
              until: CalendarDate(2026, 10, 1),
            ),
          );

          // Then
          expect(
            result.failureOrNull,
            isA<BalanceSnapshotPersistenceFailure>(),
          );
        },
      );

      test(
        'latest query translates matching corrupt record to typed failure',
        () async {
          // Given
          final older = _accountSnapshot(
            accountId: 'corrupt-latest',
            date: CalendarDate(2026, 9, 18),
          );

          final newer = _accountSnapshot(
            accountId: 'corrupt-latest',
            date: CalendarDate(2026, 9, 19),
          );

          await repository.save(older);

          final model = BalanceSnapshotPersistenceModel.fromEntity(newer);

          final corruptRecord = <String, Object?>{
            ...model.toRecord(),
            BalanceSnapshotPersistenceModel.snapshotDateField: '2026-09-18',
          };

          await SembastStores.balanceSnapshots
              .record(model.recordKey)
              .put(database, corruptRecord);

          // When
          final result = await repository.getLatest(newer.subject);

          // Then
          expect(
            result.failureOrNull,
            isA<BalanceSnapshotPersistenceFailure>(),
          );
        },
      );

      test(
        'corrupt record for another subject does not poison query',
        () async {
          // Given
          final valid = _accountSnapshot(
            accountId: 'valid-account',
            date: CalendarDate(2026, 9, 19),
          );

          await repository.save(valid);

          final corrupt = _accountSnapshot(
            accountId: 'corrupt-other-account',
            date: CalendarDate(2026, 9, 19),
          );

          final corruptModel = BalanceSnapshotPersistenceModel.fromEntity(
            corrupt,
          );

          await SembastStores.balanceSnapshots
              .record(corruptModel.recordKey)
              .put(database, <String, Object?>{
                ...corruptModel.toRecord(),
                BalanceSnapshotPersistenceModel.recordVersionField: 999,
              });

          // When
          final result = await repository.getLatest(valid.subject);

          // Then
          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull, valid);
        },
      );
    });
  });
}

BalanceSnapshot _accountSnapshot({
  String accountId = 'account-1',
  CalendarDate? date,
  DateTime? capturedAt,
  String assetAmount = '100',
  String denominationAmount = '90',
  String valuationAmount = '95',
}) {
  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.account(AccountId.fromString(accountId)),
    snapshotDate: date ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 20, 2),
    assetBalances: <AssetAmount>[_incoming('asset-usd', assetAmount)],
    denominationAmount: _incoming('asset-eur', denominationAmount),
    valuationAmount: _incoming('asset-chf', valuationAmount),
  );
}

BalanceSnapshot _custodianSnapshot({
  String custodianId = 'custodian-1',
  CalendarDate? date,
  DateTime? capturedAt,
  String amount = '100',
}) {
  final total = _incoming('asset-chf', amount);

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.custodian(
      CustodianId.fromString(custodianId),
    ),
    snapshotDate: date ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 20, 2),
    assetBalances: <AssetAmount>[total],
    denominationAmount: total,
    valuationAmount: total,
  );
}

BalanceSnapshot _jarSnapshot({
  String jarId = 'jar-1',
  CalendarDate? date,
  DateTime? capturedAt,
  String amount = '100',
}) {
  final total = _incoming('asset-chf', amount);

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.jar(JarId.fromString(jarId)),
    snapshotDate: date ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 20, 2),
    assetBalances: <AssetAmount>[total],
    denominationAmount: total,
    valuationAmount: total,
  );
}

AssetAmount _incoming(String assetId, String amount) {
  return AssetAmount.incoming(
    assetId: AssetId.fromString(assetId),
    amount: Decimal.parse(amount),
  );
}
