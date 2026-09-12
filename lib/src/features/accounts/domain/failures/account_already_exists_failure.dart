import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_already_exists_failure.mapper.dart';

/// Indicates that an account conflicts with an existing account.
@MappableClass()
final class AccountAlreadyExistsFailure
    extends Failure<AccountAlreadyExistsFailure>
    with AccountAlreadyExistsFailureMappable
    implements AccountFailure {
  /// Creates an account-already-exists failure with optional details.
  const AccountAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountAlreadyExists';

  @override
  AccountAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
