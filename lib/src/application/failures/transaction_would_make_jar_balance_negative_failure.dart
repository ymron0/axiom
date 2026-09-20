import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_would_make_jar_balance_negative_failure.mapper.dart';

/// Indicates that strict jar-balance enforcement rejected a transaction because
/// it would create or worsen a negative jar balance.
@MappableClass()
final class TransactionWouldMakeJarBalanceNegativeFailure
    extends Failure<TransactionWouldMakeJarBalanceNegativeFailure>
    with TransactionWouldMakeJarBalanceNegativeFailureMappable {
  /// Stable identifier for this failure kind.
  static const typeId = 'application.transactionWouldMakeJarBalanceNegative';

  /// Creates a negative-jar-balance failure.
  const TransactionWouldMakeJarBalanceNegativeFailure({required String message})
    : super(message);

  @override
  TransactionWouldMakeJarBalanceNegativeFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
