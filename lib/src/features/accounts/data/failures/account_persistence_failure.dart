import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_persistence_failure.mapper.dart';

/// Indicates that account persistence could not complete successfully.
///
/// This failure represents storage-level problems exposed through the Accounts
/// domain failure contract.
///
/// Infrastructure-specific failures and exceptions must not escape through
/// `AccountRepository`. Persistent repository implementations translate
/// expected storage problems into this failure instead.
///
/// Examples include:
///
/// - Sembast database failures,
/// - file-system failures,
/// - malformed persisted account records,
/// - persisted account records that cannot be reconstructed according to the
///   current domain invariants.
///
/// Programmer errors and violated internal assumptions are deliberately not
/// translated into this failure and must continue to propagate normally.
@MappableClass()
final class AccountPersistenceFailure extends Failure<AccountPersistenceFailure>
    with AccountPersistenceFailureMappable
    implements AccountFailure {
  /// Creates an account-persistence failure with optional details.
  const AccountPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.persistence';

  @override
  AccountPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
