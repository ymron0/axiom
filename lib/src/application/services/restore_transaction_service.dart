import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Restores a transaction after validating its cross-feature allocations.
final class RestoreTransactionService {
  /// Creates a transaction restoration workflow using the supplied dependencies.
  const RestoreTransactionService({
    required RestoreTransactionUseCase restoreTransaction,
    required ValidateTransactionAllocationsService validateAllocations,
  }) : _restoreTransaction = // ignore: prefer_initializing_formals
           restoreTransaction,
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations;

  final RestoreTransactionUseCase _restoreTransaction;
  final ValidateTransactionAllocationsService _validateAllocations;

  /// Validates and restores [transaction].
  ///
  /// Returns failures from allocation validation or transaction persistence.
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final validationResult = await _validateAllocations(transaction);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _restoreTransaction(transaction);
  }
}
