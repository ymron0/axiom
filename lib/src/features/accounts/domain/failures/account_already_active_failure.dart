import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_already_active_failure.mapper.dart';

/// Indicates that an account is already active.
@MappableClass()
final class AccountAlreadyActiveFailure
    extends Failure<AccountAlreadyActiveFailure>
    with AccountAlreadyActiveFailureMappable
    implements AccountFailure {
  /// Creates an account-already-active failure with optional details.
  const AccountAlreadyActiveFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountAlreadyActive';

  @override
  AccountAlreadyActiveFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
