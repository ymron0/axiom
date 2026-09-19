@Tags(['application'])
library;

import 'package:axiom/src/application/models/historical_balance_point.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('HistoricalBalancePoint', () {
    test('available uses subject and date from snapshot', () {
      // Given
      final snapshot = _snapshot(
        date: CalendarDate(2026, 9, 19),
        amount: '125',
      );

      // When
      final point = HistoricalBalancePoint.available(snapshot);

      // Then
      expect(point.subject, snapshot.subject);
      expect(point.date, snapshot.snapshotDate);
      expect(point.snapshot, same(snapshot));
      expect(point.isMissing, isFalse);
    });

    test('missing explicitly represents a date without a snapshot', () {
      // Given
      final subject = BalanceSnapshotSubject.account(
        AccountId.fromString('account-1'),
      );
      final date = CalendarDate(2026, 9, 18);

      // When
      final point = HistoricalBalancePoint.missing(
        subject: subject,
        date: date,
      );

      // Then
      expect(point.subject, subject);
      expect(point.date, date);
      expect(point.snapshot, isNull);
      expect(point.isMissing, isTrue);
    });
  });
}

BalanceSnapshot _snapshot({
  required CalendarDate date,
  required String amount,
}) {
  final assetId = AssetId.fromString('currency-chf');
  final balance = AssetAmount.incoming(
    assetId: assetId,
    amount: Decimal.parse(amount),
  );

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.account(AccountId.fromString('account-1')),
    snapshotDate: date,
    capturedAt: DateTime.utc(date.year, date.month, date.day, 23, 59),
    assetBalances: [balance],
    denominationAmount: balance,
    valuationAmount: balance,
  );
}
