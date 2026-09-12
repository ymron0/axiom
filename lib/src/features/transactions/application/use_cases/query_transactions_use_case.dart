import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves active persisted transactions matching query criteria.
final class QueryTransactionsUseCase {
  /// Creates a use case backed by [repository].
  QueryTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  /// Returns active persisted transactions matching [query].
  ///
  /// Matching and empty-criterion semantics are defined by
  /// [TransactionQuery]. Returns an empty list when nothing matches, or a
  /// [TransactionFailure] when retrieval fails.
  Future<Result<List<Transaction>, TransactionFailure>> call(
    TransactionQuery query,
  ) {
    return _repository.query(query);
  }
}
