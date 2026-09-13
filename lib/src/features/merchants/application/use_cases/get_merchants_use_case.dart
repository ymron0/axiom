import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Retrieves all active persisted merchants.
final class GetMerchantsUseCase {
  /// Creates a use case backed by [repository].
  GetMerchantsUseCase(this._repository);

  final MerchantRepository _repository;

  /// Returns all active persisted merchants.
  ///
  /// Returns an empty list when none exist, or a [MerchantFailure] when
  /// retrieval fails.
  Future<Result<List<Merchant>, MerchantFailure>> call() {
    return _repository.getAll();
  }
}
