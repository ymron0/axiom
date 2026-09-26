import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Reactive account queries intended for long-lived presentation reads.
///
/// ## Semantics
///
/// Each operation observes persistence and emits a new typed [Result] whenever
/// the relevant persisted account data changes.
///
/// ## Contract
///
/// This class does not own persistence lifecycle or cache state. Subscription
/// lifecycle is owned by the caller, normally Riverpod.
final class AccountWatchQueries {
  final AccountRepository _repository;

  /// Creates reactive account queries backed by [repository].
  AccountWatchQueries(this._repository);

  /// Watches every persisted account.
  Stream<Result<List<Account>, AccountFailure>> all() {
    return _repository.watchAll();
  }

  /// Watches every active persisted account.
  Stream<Result<List<Account>, AccountFailure>> active() {
    return _repository.watchActive();
  }

  /// Watches every archived persisted account.
  Stream<Result<List<Account>, AccountFailure>> archived() {
    return _repository.watchArchived();
  }

  /// Watches one account by identity.
  Stream<Result<Account?, AccountFailure>> byId(AccountId id) {
    return _repository.watchById(id);
  }

  /// Watches accounts belonging to [custodianId].
  Stream<Result<List<Account>, AccountFailure>> byCustodianId(
    CustodianId custodianId,
  ) {
    return _repository.watchByCustodianId(custodianId);
  }
}
