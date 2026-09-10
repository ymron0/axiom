// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_kind.mapper.dart';

/// Describes the economic meaning of a transaction.
///
/// Each transaction has exactly one kind. The kind records business intent
/// explicitly because the shape of its account movements is not always
/// sufficient to distinguish the event.
@MappableEnum()
enum TransactionKind {
  /// Payment or consumption of value.
  expense,

  /// Ordinary incoming value, such as salary.
  income,

  /// Movement between accounts, possibly with asset conversion.
  transfer,

  /// Manual increase or decrease aligning an account with an observed balance.
  balanceCorrection,
}

/// Domain policies associated with a [TransactionKind].
extension TransactionKindDomain on TransactionKind {
  /// Whether transactions of this kind support allocation splits.
  ///
  /// Expense and income transactions may allocate their economic amount across
  /// budgets, categories, or jars.
  ///
  /// Transfers and balance corrections do not represent allocatable spending or
  /// income and therefore do not support splits.
  bool get supportsSplits => switch (this) {
    TransactionKind.expense || TransactionKind.income => true,
    TransactionKind.transfer || TransactionKind.balanceCorrection => false,
  };
}
