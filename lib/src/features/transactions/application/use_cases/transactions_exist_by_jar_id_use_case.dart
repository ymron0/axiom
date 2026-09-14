import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Determines whether persisted transactions reference a jar.
class TransactionsExistByJarIdUseCase {
  final TransactionRepository _repository;

  /// Creates a use case backed by [repository].
  TransactionsExistByJarIdUseCase(this._repository);

  /// Returns whether at least one persisted transaction references [jarId].
  Future<Result<bool, TransactionFailure>> call(JarId jarId) {
    return _repository.existsByJarId(jarId);
  }
}
