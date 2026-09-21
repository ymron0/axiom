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

  /// Acquisition of a non-cash asset in exchange for a settlement asset.
  buy,

  /// Disposal of a non-cash asset in exchange for a settlement asset.
  sell,

  /// Distribution received from an investment.
  ///
  /// The received asset may itself be cash or another asset.
  dividend,

  /// Reward received independently of an ordinary income payment.
  ///
  /// Examples include staking rewards and other asset rewards.
  reward,
}

/// Domain policies associated with a [TransactionKind].
extension TransactionKindDomain on TransactionKind {
  /// Whether transactions of this kind support allocation splits.
  ///
  /// Existing category/jar allocation semantics remain limited to expense and
  /// income transactions.
  bool get supportsSplits => switch (this) {
    TransactionKind.expense || TransactionKind.income => true,
    TransactionKind.transfer ||
    TransactionKind.balanceCorrection ||
    TransactionKind.buy ||
    TransactionKind.sell ||
    TransactionKind.dividend ||
    TransactionKind.reward => false,
  };
}
