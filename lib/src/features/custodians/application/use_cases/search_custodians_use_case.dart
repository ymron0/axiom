import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Searches active persisted custodians by name.
final class SearchCustodiansUseCase {
  /// Creates a use case backed by [repository].
  SearchCustodiansUseCase(this._repository);

  final CustodianRepository _repository;

  /// Returns active custodians matching [query].
  ///
  /// Matching and empty-query semantics are defined by the repository.
  Future<Result<List<Custodian>, CustodianFailure>> call(String query) {
    return _repository.search(query);
  }
}
