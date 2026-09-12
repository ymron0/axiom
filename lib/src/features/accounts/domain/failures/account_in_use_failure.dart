import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_in_use_failure.mapper.dart';

/// Indicates that an account is referenced by at least one transaction.
@MappableClass()
final class AccountInUseFailure extends Failure<AccountInUseFailure>
    with AccountInUseFailureMappable
    implements AccountFailure {
  /// Creates an account-in-use failure with optional details.
  const AccountInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountInUse';

  @override
  AccountInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
