import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_repository_failure.mapper.dart';

/// Indicates that an account repository operation could not complete.
@MappableClass()
final class AccountRepositoryFailure extends Failure<AccountRepositoryFailure>
    with AccountRepositoryFailureMappable
    implements AccountFailure {
  /// Creates an account repository failure with optional details.
  const AccountRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'accounts.repository';

  @override
  AccountRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
