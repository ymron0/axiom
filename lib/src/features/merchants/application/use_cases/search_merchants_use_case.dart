import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Searches active persisted merchants by name.
final class SearchMerchantsUseCase {
  /// Creates a use case backed by [repository].
  SearchMerchantsUseCase(this._repository);

  final MerchantRepository _repository;

  /// Returns active merchants matching [query].
  ///
  /// Matching and empty-query semantics are defined by the repository.
  Future<Result<List<Merchant>, MerchantFailure>> call(String query) {
    return _repository.search(query);
  }
}
