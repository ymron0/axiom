import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves persisted transactions allocated to one jar.
final class GetTransactionsByJarIdUseCase {
  final TransactionRepository _repository;

  /// Creates a use case backed by [repository].
  const GetTransactionsByJarIdUseCase(this._repository);

  /// Returns transactions containing at least one allocation to [jarId].
  ///
  /// Ordering and empty-result semantics are defined by
  /// [TransactionRepository.getTransactionsByJarId].
  Future<Result<List<Transaction>, TransactionFailure>> call(
    JarId jarId,
  ) {
    return _repository.getTransactionsByJarId(jarId);
  }
}