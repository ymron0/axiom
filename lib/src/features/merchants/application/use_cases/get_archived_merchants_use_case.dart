import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Returns persisted merchants that are archived.
final class GetArchivedMerchantsUseCase {
  /// Creates a use case backed by [repository].
  GetArchivedMerchantsUseCase(this._repository);

  final MerchantRepository _repository;

  /// Returns every archived persisted merchant.
  Future<Result<List<Merchant>, MerchantFailure>> call() {
    return _repository.getArchived();
  }
}
