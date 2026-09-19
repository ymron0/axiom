@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_exceeds_available_amount_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_offset_fixtures.dart';

void main() {
  group('TransactionOffsetPolicy', () {
    const policy = TransactionOffsetPolicy();

    test('accepts a valid partial reimbursement', () {
      final original = offsetOriginalTransactionFixture();
      final offset = offsetTransactionFixture();

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.isSuccess, isTrue);
    });

    test('accepts multiple offsets up to original amount', () {
      final original = offsetOriginalTransactionFixture();
      final first = offsetTransactionFixture(
        id: 'first',
        amount: Decimal.fromInt(40),
      );
      final second = offsetTransactionFixture(
        id: 'second',
        amount: Decimal.fromInt(60),
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: second,
        existingOffsets: [first],
      );

      expect(result.isSuccess, isTrue);
    });

    test('rejects cumulative offsets above original amount', () {
      final original = offsetOriginalTransactionFixture();
      final first = offsetTransactionFixture(
        id: 'first',
        amount: Decimal.fromInt(60),
      );
      final second = offsetTransactionFixture(
        id: 'second',
        amount: Decimal.fromInt(50),
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: second,
        existingOffsets: [first],
      );

      expect(
        result.failureOrNull,
        isA<TransactionOffsetExceedsAvailableAmountFailure>(),
      );
    });

    test('rejects a planned original transaction', () {
      final original = offsetOriginalTransactionFixture(
        state: TransactionState.planned,
      );

      final result = policy.validateOriginal(original);

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects a balance correction as an original transaction', () {
      final original = offsetOriginalTransactionFixture(
        kind: TransactionKind.balanceCorrection,
      );

      final result = policy.validateOriginal(original);

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects a planned offset', () {
      final original = offsetOriginalTransactionFixture();
      final offset = offsetTransactionFixture(state: TransactionState.planned);

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects an offset using the wrong transaction kind', () {
      final original = offsetOriginalTransactionFixture();
      final offset = offsetTransactionFixture(kind: TransactionKind.expense);

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects an offset effective before original', () {
      final original = offsetOriginalTransactionFixture(
        effectiveAt: DateTime.utc(2026, 1, 10),
      );
      final offset = offsetTransactionFixture(
        effectiveAt: DateTime.utc(2026, 1, 9),
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects an offset using another transaction asset', () {
      final original = offsetOriginalTransactionFixture();
      final offset = offsetTransactionFixture(
        assetId: AssetId.fromString('asset-eur'),
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('rejects zero offset amount', () {
      final original = offsetOriginalTransactionFixture();
      final offset = offsetTransactionFixture(amount: Decimal.zero);

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('accepts matching allocation targets', () {
      final categoryId = CategoryId.fromString('restaurants');

      final original = offsetOriginalTransactionFixture(categoryId: categoryId);

      final offset = offsetTransactionFixture(categoryId: categoryId);

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.isSuccess, isTrue);
    });

    test('rejects allocation target absent from original', () {
      final original = offsetOriginalTransactionFixture(
        categoryId: CategoryId.fromString('restaurants'),
      );

      final offset = offsetTransactionFixture(
        categoryId: CategoryId.fromString('groceries'),
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test('prevents cumulative over-offset of one allocation target', () {
      final categoryId = CategoryId.fromString('restaurants');
      final otherCategoryId = CategoryId.fromString('groceries');

      final original = offsetOriginalTransactionFixture(
        amount: Decimal.fromInt(100),
        allocations: [
          (categoryId: categoryId, amount: Decimal.fromInt(60)),
          (categoryId: otherCategoryId, amount: Decimal.fromInt(40)),
        ],
      );

      final first = offsetTransactionFixture(
        id: 'first',
        amount: Decimal.fromInt(60),
        categoryId: categoryId,
      );

      final second = offsetTransactionFixture(
        id: 'second',
        amount: Decimal.fromInt(40),
        categoryId: categoryId,
      );

      final result = policy.validateNewOffset(
        original: original,
        offset: second,
        existingOffsets: [first],
      );

      expect(
        result.failureOrNull,
        isA<TransactionOffsetExceedsAvailableAmountFailure>(),
      );
    });
  });
}
