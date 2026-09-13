import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Replaces one active persisted merchant snapshot.
final class UpdateMerchantUseCase {
  /// Creates a use case backed by [repository].
  UpdateMerchantUseCase(this._repository);

  final MerchantRepository _repository;

  /// Replaces the persisted snapshot for [merchant].
  ///
  /// Returns a [MerchantFailure] when the merchant is deleted or absent from
  /// persistence.
  Future<Result<void, MerchantFailure>> call(Merchant merchant) {
    return _repository.update(merchant);
  }
}
