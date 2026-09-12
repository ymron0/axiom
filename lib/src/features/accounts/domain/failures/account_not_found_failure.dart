import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_not_found_failure.mapper.dart';

/// Indicates that an expected account does not exist.
@MappableClass()
final class AccountNotFoundFailure extends Failure<AccountNotFoundFailure>
    with AccountNotFoundFailureMappable
    implements AccountFailure {
  /// Creates an account-not-found failure with optional details.
  const AccountNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountNotFound';

  @override
  AccountNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
