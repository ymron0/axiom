import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_already_archived_failure.mapper.dart';

/// Indicates that an account is already archived.
@MappableClass()
final class AccountAlreadyArchivedFailure
    extends Failure<AccountAlreadyArchivedFailure>
    with AccountAlreadyArchivedFailureMappable
    implements AccountFailure {
  /// Creates an account-already-archived failure.
  const AccountAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountAlreadyArchived';

  @override
  AccountAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
