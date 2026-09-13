import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Retrieves all active persisted custodians.
final class GetCustodiansUseCase {
  /// Creates a use case backed by [repository].
  GetCustodiansUseCase(this._repository);

  final CustodianRepository _repository;

  /// Returns all active persisted custodians.
  ///
  /// Returns an empty list when none exist, or a [CustodianFailure] when
  /// retrieval fails.
  Future<Result<List<Custodian>, CustodianFailure>> call() {
    return _repository.getAll();
  }
}
