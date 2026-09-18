import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Determines whether persisted transaction series reference a merchant.
///
/// Both active and archived series participate in the lookup.
final class TransactionSeriesExistByMerchantIdUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const TransactionSeriesExistByMerchantIdUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Whether at least one persisted series references [merchantId].
  Future<Result<bool, TransactionSeriesFailure>> call(MerchantId merchantId) {
    return _repository.existsByMerchantId(merchantId);
  }
}
