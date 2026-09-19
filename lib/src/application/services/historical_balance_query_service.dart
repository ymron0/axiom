import 'package:axiom/src/application/models/historical_balance_point.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';

/// Provides read-only historical balance queries for supported snapshot
/// subjects.
///
/// Exact-date queries preserve strict date semantics: if no snapshot exists
/// for the requested date, the returned [HistoricalBalancePoint] explicitly
/// represents that date as missing.
///
/// In particular, this service never substitutes an earlier/latest snapshot
/// for an exact-date request.
///
/// Date-range queries return one point for every calendar date in the
/// repository's `[from, until)` range semantics. Missing dates are represented
/// by points whose snapshot is null.
///
/// This makes range results directly suitable for future time-series
/// presentation without forcing presentation code to infer gaps.
final class HistoricalBalanceQueryService {
  HistoricalBalanceQueryService(this._repository);

  final BalanceSnapshotRepository _repository;

  /// Returns the account balance snapshot for exactly [snapshotDate].
  ///
  /// A successful missing lookup returns a missing
  /// [HistoricalBalancePoint], not an older snapshot.
  Future<Result<HistoricalBalancePoint, BalanceSnapshotFailure>>
  getAccountByDate({
    required AccountId accountId,
    required CalendarDate snapshotDate,
  }) {
    return _getByDate(
      subject: BalanceSnapshotSubject.account(accountId),
      snapshotDate: snapshotDate,
    );
  }

  /// Returns one daily historical balance point for the account for every
  /// date in [range].
  ///
  /// The range is `[from, until)`.
  Future<Result<List<HistoricalBalancePoint>, BalanceSnapshotFailure>>
  getAccountByDateRange({
    required AccountId accountId,
    required BalanceSnapshotDateRange range,
  }) {
    return _getByDateRange(
      subject: BalanceSnapshotSubject.account(accountId),
      range: range,
    );
  }

  /// Returns the custodian balance snapshot for exactly [snapshotDate].
  ///
  /// A successful missing lookup returns a missing
  /// [HistoricalBalancePoint], not an older snapshot.
  Future<Result<HistoricalBalancePoint, BalanceSnapshotFailure>>
  getCustodianByDate({
    required CustodianId custodianId,
    required CalendarDate snapshotDate,
  }) {
    return _getByDate(
      subject: BalanceSnapshotSubject.custodian(custodianId),
      snapshotDate: snapshotDate,
    );
  }

  /// Returns one daily historical balance point for the custodian for every
  /// date in [range].
  ///
  /// The range is `[from, until)`.
  Future<Result<List<HistoricalBalancePoint>, BalanceSnapshotFailure>>
  getCustodianByDateRange({
    required CustodianId custodianId,
    required BalanceSnapshotDateRange range,
  }) {
    return _getByDateRange(
      subject: BalanceSnapshotSubject.custodian(custodianId),
      range: range,
    );
  }

  /// Returns the jar balance snapshot for exactly [snapshotDate].
  ///
  /// A successful missing lookup returns a missing
  /// [HistoricalBalancePoint], not an older snapshot.
  Future<Result<HistoricalBalancePoint, BalanceSnapshotFailure>> getJarByDate({
    required JarId jarId,
    required CalendarDate snapshotDate,
  }) {
    return _getByDate(
      subject: BalanceSnapshotSubject.jar(jarId),
      snapshotDate: snapshotDate,
    );
  }

  /// Returns one daily historical balance point for the jar for every date in
  /// [range].
  ///
  /// The range is `[from, until)`.
  Future<Result<List<HistoricalBalancePoint>, BalanceSnapshotFailure>>
  getJarByDateRange({
    required JarId jarId,
    required BalanceSnapshotDateRange range,
  }) {
    return _getByDateRange(
      subject: BalanceSnapshotSubject.jar(jarId),
      range: range,
    );
  }

  Future<Result<HistoricalBalancePoint, BalanceSnapshotFailure>> _getByDate({
    required BalanceSnapshotSubject subject,
    required CalendarDate snapshotDate,
  }) async {
    final result = await _repository.getByDate(
      subject: subject,
      snapshotDate: snapshotDate,
    );

    if (result case final Failure<BalanceSnapshotFailure> failure) {
      return failure;
    }

    final snapshot = result.valueOrNull;

    if (snapshot == null) {
      return Success(
        HistoricalBalancePoint.missing(subject: subject, date: snapshotDate),
      );
    }

    return Success(HistoricalBalancePoint.available(snapshot));
  }

  Future<Result<List<HistoricalBalancePoint>, BalanceSnapshotFailure>>
  _getByDateRange({
    required BalanceSnapshotSubject subject,
    required BalanceSnapshotDateRange range,
  }) async {
    final result = await _repository.getByDateRange(
      subject: subject,
      range: range,
    );

    if (result case final Failure<BalanceSnapshotFailure> failure) {
      return failure;
    }

    final snapshots = result.valueOrNull!;

    // Key explicitly by persisted calendar-date semantics rather than relying
    // on repository ordering. This also ensures deterministic output if a
    // different repository implementation returns the same records in another
    // order.
    final snapshotsByDate = <String, BalanceSnapshot>{
      for (final snapshot in snapshots)
        snapshot.snapshotDate.toString(): snapshot,
    };

    final points = <HistoricalBalancePoint>[];

    var cursor = range.from.toDateTimeUtc();
    final until = range.until.toDateTimeUtc();

    while (cursor.isBefore(until)) {
      final date = CalendarDate.fromDateTime(cursor);
      final snapshot = snapshotsByDate[date.toString()];

      if (snapshot == null) {
        points.add(
          HistoricalBalancePoint.missing(subject: subject, date: date),
        );
      } else {
        points.add(HistoricalBalancePoint.available(snapshot));
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    return Success(List.unmodifiable(points));
  }
}
