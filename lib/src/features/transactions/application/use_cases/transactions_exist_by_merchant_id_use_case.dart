import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Determines whether persisted transactions are associated with a merchant.
class TransactionsExistByMerchantIdUseCase {
  /// Creates a use case backed by [repository].
  TransactionsExistByMerchantIdUseCase(this._repository);

  final TransactionRepository _repository;

  /// Whether at least one persisted transaction references [merchantId].
  Future<Result<bool, TransactionFailure>> call(MerchantId merchantId) {
    return _repository.existsByMerchantId(merchantId);
  }
}
