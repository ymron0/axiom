import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves an active persisted transaction by identifier.
final class GetTransactionByIdUseCase {
  /// Creates a use case backed by [repository].
  GetTransactionByIdUseCase(this._repository);

  final TransactionRepository _repository;

  /// Returns the active transaction matching [id].
  ///
  /// Returns `null` when [id] is not persisted, or a [TransactionFailure] when
  /// retrieval fails.
  Future<Result<Transaction?, TransactionFailure>> call(TransactionId id) {
    return _repository.getById(id);
  }
}
