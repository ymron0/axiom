import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_already_deleted_failure.mapper.dart';

/// Indicates that an account is already marked as deleted.
@MappableClass()
final class AccountAlreadyDeletedFailure
    extends Failure<AccountAlreadyDeletedFailure>
    with AccountAlreadyDeletedFailureMappable
    implements AccountFailure {
  /// Creates an account-already-deleted failure with optional details.
  const AccountAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.accountAlreadyDeleted';

  @override
  AccountAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
