import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Restores a caller-retained, physically deleted merchant snapshot.
final class RestoreMerchantUseCase {
  /// Creates a use case backed by [repository].
  RestoreMerchantUseCase(this._repository);

  final MerchantRepository _repository;

  /// Restores [merchant] as an active persisted merchant.
  ///
  /// Returns a [MerchantFailure] when the snapshot is active already or its
  /// identity is already persisted.
  Future<Result<void, MerchantFailure>> call(Merchant merchant) {
    return _repository.restore(merchant);
  }
}
