import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived account received an
/// active account.
@MappableClass()
final class AccountNotArchivedFailure
    extends Failure<AccountNotArchivedFailure>
    with AccountNotArchivedFailureMappable
    implements AccountFailure {
  /// Creates an account-not-archived failure.
  const AccountNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountNotArchived';

  @override
  AccountNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
