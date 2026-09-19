import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves active transactions that offset one original transaction.
final class GetTransactionOffsetsUseCase {
  /// Creates a use case backed by [repository].
  const GetTransactionOffsetsUseCase({
    required TransactionRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  final TransactionRepository _repository;

  /// Returns active offsets referencing [transactionId].
  Future<Result<List<Transaction>, TransactionFailure>> call(
    TransactionId transactionId,
  ) {
    return _repository.getOffsetsForTransaction(transactionId);
  }
}
