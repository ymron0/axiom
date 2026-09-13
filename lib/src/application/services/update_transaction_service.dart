import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Updates a transaction after validating its cross-feature allocations.
final class UpdateTransactionService {
  /// Creates a transaction update workflow using the supplied dependencies.
  const UpdateTransactionService({
    required UpdateTransactionUseCase updateTransaction,
    required ValidateTransactionAllocationsService validateAllocations,
  }) : _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction,
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations;

  final UpdateTransactionUseCase _updateTransaction;
  final ValidateTransactionAllocationsService _validateAllocations;

  /// Validates and persists [transaction].
  ///
  /// Returns failures from allocation validation or transaction persistence.
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final validationResult = await _validateAllocations(transaction);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _updateTransaction(transaction);
  }
}
