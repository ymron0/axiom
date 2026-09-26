import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Reactive transaction queries intended for presentation reads.
///
/// ## Semantics
///
/// Repository query semantics remain authoritative. This class only exposes
/// those operations as the reactive read boundary used by presentation.
final class TransactionWatchQueries {
  final TransactionRepository _repository;

  /// Creates reactive transaction queries backed by [repository].
  TransactionWatchQueries(this._repository);

  /// Watches every persisted transaction.
  Stream<Result<List<Transaction>, TransactionFailure>> all() {
    return _repository.watchAll();
  }

  /// Watches one transaction by identity.
  Stream<Result<Transaction?, TransactionFailure>> byId(TransactionId id) {
    return _repository.watchById(id);
  }

  /// Watches transactions affecting [accountId].
  Stream<Result<List<Transaction>, TransactionFailure>> byAccountId(
    AccountId accountId,
  ) {
    return _repository.watchTransactionsByAccountId(accountId);
  }

  /// Watches transactions allocated to [categoryId].
  Stream<Result<List<Transaction>, TransactionFailure>> byCategoryId(
    CategoryId categoryId,
  ) {
    return _repository.watchTransactionsByCategoryId(categoryId);
  }

  /// Watches transactions allocated to [jarId].
  Stream<Result<List<Transaction>, TransactionFailure>> byJarId(JarId jarId) {
    return _repository.watchTransactionsByJarId(jarId);
  }

  /// Watches transactions matching [query].
  Stream<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  ) {
    return _repository.watchQuery(query);
  }
}
