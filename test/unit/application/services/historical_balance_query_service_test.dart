@Tags(['application'])
library;

import 'package:axiom/src/application/services/historical_balance_query_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

part 'historical_balance_query_service_test.mapper.dart';

void main() {
  late _FakeBalanceSnapshotRepository repository;
  late HistoricalBalanceQueryService service;

  setUp(() {
    repository = _FakeBalanceSnapshotRepository();
    service = HistoricalBalanceQueryService(repository);
  });

  group('exact-date queries', () {
    test(
      'returns available account snapshot for exact requested date',
      () async {
        // Given
        final accountId = AccountId.fromString('account-1');
        final date = CalendarDate(2026, 9, 19);

        final snapshot = _accountSnapshot(
          accountId: accountId,
          date: date,
          amount: '125',
        );

        repository.byDateResult = Success<BalanceSnapshot?>(snapshot);

        // When
        final result = await service.getAccountByDate(
          accountId: accountId,
          snapshotDate: date,
        );

        // Then
        expect(result.isSuccess, isTrue);

        final point = result.valueOrNull!;

        expect(point.isMissing, isFalse);
        expect(point.date, date);
        expect(point.subject, BalanceSnapshotSubject.account(accountId));
        expect(point.snapshot, same(snapshot));

        expect(
          repository.lastByDateSubject,
          BalanceSnapshotSubject.account(accountId),
        );
        expect(repository.lastByDateSnapshotDate, date);

        // Exact queries must never silently substitute the latest snapshot.
        expect(repository.getLatestCallCount, 0);
      },
    );

    test(
      'returns explicit missing account point when exact date has no snapshot',
      () async {
        // Given
        final accountId = AccountId.fromString('account-1');
        final requestedDate = CalendarDate(2026, 9, 19);

        repository.byDateResult = const Success<BalanceSnapshot?>(null);

        // When
        final result = await service.getAccountByDate(
          accountId: accountId,
          snapshotDate: requestedDate,
        );

        // Then
        expect(result.isSuccess, isTrue);

        final point = result.valueOrNull!;

        expect(point.subject, BalanceSnapshotSubject.account(accountId));
        expect(point.date, requestedDate);
        expect(point.snapshot, isNull);
        expect(point.isMissing, isTrue);

        // This is the critical S12.06 semantic:
        // do not fall back to an earlier/latest balance.
        expect(repository.getLatestCallCount, 0);
      },
    );

    test('queries exact custodian subject', () async {
      // Given
      final custodianId = CustodianId.fromString('custodian-1');
      final date = CalendarDate(2026, 9, 19);

      final snapshot = _custodianSnapshot(
        custodianId: custodianId,
        date: date,
        amount: '500',
      );

      repository.byDateResult = Success<BalanceSnapshot?>(snapshot);

      // When
      final result = await service.getCustodianByDate(
        custodianId: custodianId,
        snapshotDate: date,
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.snapshot, same(snapshot));

      expect(
        repository.lastByDateSubject,
        BalanceSnapshotSubject.custodian(custodianId),
      );
      expect(repository.lastByDateSnapshotDate, date);
    });

    test('queries exact jar subject', () async {
      // Given
      final jarId = JarId.fromString('jar-1');
      final date = CalendarDate(2026, 9, 19);

      final snapshot = _jarSnapshot(jarId: jarId, date: date, amount: '75');

      repository.byDateResult = Success<BalanceSnapshot?>(snapshot);

      // When
      final result = await service.getJarByDate(
        jarId: jarId,
        snapshotDate: date,
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.snapshot, same(snapshot));

      expect(repository.lastByDateSubject, BalanceSnapshotSubject.jar(jarId));
      expect(repository.lastByDateSnapshotDate, date);
    });

    test('propagates exact-date repository failure unchanged', () async {
      // Given
      const failure = TestBalanceSnapshotFailure(
        message: 'Exact-date lookup failed.',
      );

      repository.byDateResult = failure;

      // When
      final result = await service.getAccountByDate(
        accountId: AccountId.fromString('account-1'),
        snapshotDate: CalendarDate(2026, 9, 19),
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, same(failure));
      expect(repository.getLatestCallCount, 0);
    });
  });

  group('date-range queries', () {
    test(
      'returns one ascending point per requested date and explicitly fills gaps',
      () async {
        // Given
        final accountId = AccountId.fromString('account-1');

        final range = BalanceSnapshotDateRange(
          from: CalendarDate(2026, 9, 17),
          until: CalendarDate(2026, 9, 20),
        );

        final september17 = _accountSnapshot(
          accountId: accountId,
          date: CalendarDate(2026, 9, 17),
          amount: '100',
        );

        final september19 = _accountSnapshot(
          accountId: accountId,
          date: CalendarDate(2026, 9, 19),
          amount: '120',
        );

        // Intentionally return them in reverse order.
        //
        // The application service should still produce deterministic,
        // chronological chart data.
        repository.byDateRangeResult = Success<List<BalanceSnapshot>>([
          september19,
          september17,
        ]);

        // When
        final result = await service.getAccountByDateRange(
          accountId: accountId,
          range: range,
        );

        // Then
        expect(result.isSuccess, isTrue);

        final points = result.valueOrNull!;

        expect(points, hasLength(3));

        expect(points[0].date, CalendarDate(2026, 9, 17));
        expect(points[0].isMissing, isFalse);
        expect(points[0].snapshot, same(september17));

        expect(points[1].date, CalendarDate(2026, 9, 18));
        expect(points[1].isMissing, isTrue);
        expect(points[1].snapshot, isNull);

        expect(points[2].date, CalendarDate(2026, 9, 19));
        expect(points[2].isMissing, isFalse);
        expect(points[2].snapshot, same(september19));

        expect(
          repository.lastByDateRangeSubject,
          BalanceSnapshotSubject.account(accountId),
        );
        expect(repository.lastByDateRange, same(range));
      },
    );

    test(
      'returns all dates as missing when repository range is empty',
      () async {
        // Given
        final accountId = AccountId.fromString('account-1');

        final range = BalanceSnapshotDateRange(
          from: CalendarDate(2026, 9, 17),
          until: CalendarDate(2026, 9, 20),
        );

        repository.byDateRangeResult = const Success<List<BalanceSnapshot>>([]);

        // When
        final result = await service.getAccountByDateRange(
          accountId: accountId,
          range: range,
        );

        // Then
        expect(result.isSuccess, isTrue);

        final points = result.valueOrNull!;

        expect(points, hasLength(3));
        expect(points.map((point) => point.date), [
          CalendarDate(2026, 9, 17),
          CalendarDate(2026, 9, 18),
          CalendarDate(2026, 9, 19),
        ]);
        expect(points.every((point) => point.isMissing), isTrue);
      },
    );

    test('range result is immutable', () async {
      // Given
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 9, 19),
        until: CalendarDate(2026, 9, 20),
      );

      repository.byDateRangeResult = const Success<List<BalanceSnapshot>>([]);

      // When
      final result = await service.getAccountByDateRange(
        accountId: AccountId.fromString('account-1'),
        range: range,
      );

      // Then
      final points = result.valueOrNull!;

      expect(() => points.add(points.first), throwsUnsupportedError);
    });

    test('queries custodian range using custodian subject', () async {
      // Given
      final custodianId = CustodianId.fromString('custodian-1');

      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 9, 19),
        until: CalendarDate(2026, 9, 20),
      );

      repository.byDateRangeResult = const Success<List<BalanceSnapshot>>([]);

      // When
      final result = await service.getCustodianByDateRange(
        custodianId: custodianId,
        range: range,
      );

      // Then
      expect(result.isSuccess, isTrue);

      expect(
        repository.lastByDateRangeSubject,
        BalanceSnapshotSubject.custodian(custodianId),
      );
      expect(repository.lastByDateRange, same(range));
    });

    test('queries jar range using jar subject', () async {
      // Given
      final jarId = JarId.fromString('jar-1');

      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 9, 19),
        until: CalendarDate(2026, 9, 20),
      );

      repository.byDateRangeResult = const Success<List<BalanceSnapshot>>([]);

      // When
      final result = await service.getJarByDateRange(
        jarId: jarId,
        range: range,
      );

      // Then
      expect(result.isSuccess, isTrue);

      expect(
        repository.lastByDateRangeSubject,
        BalanceSnapshotSubject.jar(jarId),
      );
      expect(repository.lastByDateRange, same(range));
    });

    test('propagates date-range repository failure unchanged', () async {
      // Given
      const failure = TestBalanceSnapshotFailure(
        message: 'Range lookup failed.',
      );

      repository.byDateRangeResult = failure;

      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 9, 17),
        until: CalendarDate(2026, 9, 20),
      );

      // When
      final result = await service.getAccountByDateRange(
        accountId: AccountId.fromString('account-1'),
        range: range,
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, same(failure));
    });
  });
}

final class _FakeBalanceSnapshotRepository
    implements BalanceSnapshotRepository {
  Result<BalanceSnapshot?, BalanceSnapshotFailure> byDateResult =
      const Success<BalanceSnapshot?>(null);

  Result<List<BalanceSnapshot>, BalanceSnapshotFailure> byDateRangeResult =
      const Success<List<BalanceSnapshot>>([]);

  BalanceSnapshotSubject? lastByDateSubject;
  CalendarDate? lastByDateSnapshotDate;

  BalanceSnapshotSubject? lastByDateRangeSubject;
  BalanceSnapshotDateRange? lastByDateRange;

  int getLatestCallCount = 0;

  @override
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getByDate({
    required BalanceSnapshotSubject subject,
    required CalendarDate snapshotDate,
  }) async {
    lastByDateSubject = subject;
    lastByDateSnapshotDate = snapshotDate;

    return byDateResult;
  }

  @override
  Future<Result<List<BalanceSnapshot>, BalanceSnapshotFailure>> getByDateRange({
    required BalanceSnapshotSubject subject,
    required BalanceSnapshotDateRange range,
  }) async {
    lastByDateRangeSubject = subject;
    lastByDateRange = range;

    return byDateRangeResult;
  }

  @override
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getLatest(
    BalanceSnapshotSubject subject,
  ) async {
    getLatestCallCount++;

    return const Success<BalanceSnapshot?>(null);
  }

  @override
  Future<Result<void, BalanceSnapshotFailure>> save(
    BalanceSnapshot snapshot,
  ) async {
    return const Success<void>(null);
  }
}

@MappableClass()
final class TestBalanceSnapshotFailure
    extends Failure<TestBalanceSnapshotFailure>
    with TestBalanceSnapshotFailureMappable
    implements BalanceSnapshotFailure {
  const TestBalanceSnapshotFailure({String? message}) : super(message);

  static const typeId = 'test.balance_snapshot';

  @override
  TestBalanceSnapshotFailure get failureOrNull => this;

  @override
  String get type => typeId;
}

BalanceSnapshot _accountSnapshot({
  required AccountId accountId,
  required CalendarDate date,
  required String amount,
}) {
  final assetId = AssetId.fromString('currency-chf');

  final balance = AssetAmount.incoming(
    assetId: assetId,
    amount: Decimal.parse(amount),
  );

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.account(accountId),
    snapshotDate: date,
    capturedAt: DateTime.utc(2026, 9, 19, 23, 59),
    assetBalances: [balance],
    denominationAmount: balance,
    valuationAmount: balance,
  );
}

BalanceSnapshot _custodianSnapshot({
  required CustodianId custodianId,
  required CalendarDate date,
  required String amount,
}) {
  final assetId = AssetId.fromString('currency-chf');

  final balance = AssetAmount.incoming(
    assetId: assetId,
    amount: Decimal.parse(amount),
  );

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.custodian(custodianId),
    snapshotDate: date,
    capturedAt: DateTime.utc(2026, 9, 19, 23, 59),
    assetBalances: [balance],
    denominationAmount: balance,
    valuationAmount: balance,
  );
}

BalanceSnapshot _jarSnapshot({
  required JarId jarId,
  required CalendarDate date,
  required String amount,
}) {
  final assetId = AssetId.fromString('currency-chf');

  final balance = AssetAmount.incoming(
    assetId: assetId,
    amount: Decimal.parse(amount),
  );

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.jar(jarId),
    snapshotDate: date,
    capturedAt: DateTime.utc(2026, 9, 19, 23, 59),
    assetBalances: [balance],
    denominationAmount: balance,
    valuationAmount: balance,
  );
}
