import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Retrieves an active persisted merchant by identifier.
final class GetMerchantByIdUseCase {
  /// Creates a use case backed by [repository].
  GetMerchantByIdUseCase(this._repository);

  final MerchantRepository _repository;

  /// Returns the active merchant matching [id], or `null` when absent.
  Future<Result<Merchant?, MerchantFailure>> call(MerchantId id) {
    return _repository.getById(id);
  }
}
