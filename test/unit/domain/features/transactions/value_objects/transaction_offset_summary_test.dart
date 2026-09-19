@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset_summary.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_offset_fixtures.dart';

void main() {
  group('TransactionOffsetSummary', () {
    test('derives total offset and net amount', () {
      final original = offsetOriginalTransactionFixture();

      final summary = TransactionOffsetSummary(
        transactionId: original.id,
        assetId: transactionOffsetFixtureAssetId,
        grossAmount: Decimal.fromInt(100),
        refundAmount: Decimal.fromInt(20),
        reimbursementAmount: Decimal.fromInt(50),
        cashbackAmount: Decimal.fromInt(5),
        offsets: [
          offsetTransactionFixture(id: 'refund', amount: Decimal.fromInt(20)),
          offsetTransactionFixture(
            id: 'reimbursement',
            amount: Decimal.fromInt(50),
          ),
          offsetTransactionFixture(id: 'cashback', amount: Decimal.fromInt(5)),
        ],
      );

      expect(summary.totalOffsetAmount, Decimal.fromInt(75));
      expect(summary.netAmount, Decimal.fromInt(25));
      expect(summary.hasOffsets, isTrue);
      expect(summary.isPartiallyOffset, isTrue);
      expect(summary.isFullyOffset, isFalse);
    });

    test('recognizes fully offset transaction', () {
      final original = offsetOriginalTransactionFixture();

      final summary = TransactionOffsetSummary(
        transactionId: original.id,
        assetId: transactionOffsetFixtureAssetId,
        grossAmount: Decimal.fromInt(100),
        refundAmount: Decimal.fromInt(100),
        reimbursementAmount: Decimal.zero,
        cashbackAmount: Decimal.zero,
        offsets: [offsetTransactionFixture(amount: Decimal.fromInt(100))],
      );

      expect(summary.netAmount, Decimal.zero);
      expect(summary.isFullyOffset, isTrue);
    });

    test('rejects total offsets above gross amount', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.fromInt(100),
          refundAmount: Decimal.fromInt(101),
          reimbursementAmount: Decimal.zero,
          cashbackAmount: Decimal.zero,
          offsets: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive gross amount', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.zero,
          refundAmount: Decimal.zero,
          reimbursementAmount: Decimal.zero,
          cashbackAmount: Decimal.zero,
          offsets: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative refund amount', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.fromInt(100),
          refundAmount: Decimal.fromInt(-1),
          reimbursementAmount: Decimal.zero,
          cashbackAmount: Decimal.zero,
          offsets: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative reimbursement amount', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.fromInt(100),
          refundAmount: Decimal.zero,
          reimbursementAmount: Decimal.fromInt(-1),
          cashbackAmount: Decimal.zero,
          offsets: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative cashback amount', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.fromInt(100),
          refundAmount: Decimal.zero,
          reimbursementAmount: Decimal.zero,
          cashbackAmount: Decimal.fromInt(-1),
          offsets: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an offset for another transaction', () {
      final original = offsetOriginalTransactionFixture();

      expect(
        () => TransactionOffsetSummary(
          transactionId: original.id,
          assetId: transactionOffsetFixtureAssetId,
          grossAmount: Decimal.fromInt(100),
          refundAmount: Decimal.fromInt(50),
          reimbursementAmount: Decimal.zero,
          cashbackAmount: Decimal.zero,
          offsets: [offsetTransactionFixture(originalId: 'another')],
        ),
        throwsArgumentError,
      );
    });

    test('exposes an immutable offset collection', () {
      final original = offsetOriginalTransactionFixture();

      final summary = TransactionOffsetSummary(
        transactionId: original.id,
        assetId: transactionOffsetFixtureAssetId,
        grossAmount: Decimal.fromInt(100),
        refundAmount: Decimal.zero,
        reimbursementAmount: Decimal.zero,
        cashbackAmount: Decimal.zero,
        offsets: const [],
      );

      expect(
        () => summary.offsets.add(offsetTransactionFixture()),
        throwsUnsupportedError,
      );
    });
  });
}
