@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionKindDomain', () {
    test('supports splits for expense and income', () {
      for (final kind in [TransactionKind.expense, TransactionKind.income]) {
        expect(
          kind.supportsSplits,
          isTrue,
          reason: 'Expected $kind to support splits.',
        );
      }
    });

    test('does not support splits for other transaction kinds', () {
      for (final kind in [
        TransactionKind.transfer,
        TransactionKind.balanceCorrection,
        TransactionKind.buy,
        TransactionKind.sell,
        TransactionKind.dividend,
        TransactionKind.reward,
      ]) {
        expect(
          kind.supportsSplits,
          isFalse,
          reason: 'Expected $kind not to support splits.',
        );
      }
    });
  });
}
