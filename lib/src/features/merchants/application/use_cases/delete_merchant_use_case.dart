import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Physically deletes a merchant and returns its deleted snapshot.
class DeleteMerchantUseCase {
  /// Creates a use case backed by [repository].
  DeleteMerchantUseCase(this._repository);

  final MerchantRepository _repository;

  /// Deletes the merchant identified by [id].
  ///
  /// Returns the caller-retained deleted snapshot or a [MerchantFailure].
  Future<Result<Merchant, MerchantFailure>> call(MerchantId id) {
    return _repository.delete(id);
  }
}
