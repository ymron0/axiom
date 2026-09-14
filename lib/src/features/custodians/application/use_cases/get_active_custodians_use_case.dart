import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Returns persisted custodians that are not archived.
final class GetActiveCustodiansUseCase {
  /// Creates a use case backed by [repository].
  GetActiveCustodiansUseCase(this._repository);

  final CustodianRepository _repository;

  /// Returns every unarchived persisted custodian.
  Future<Result<List<Custodian>, CustodianFailure>> call() {
    return _repository.getActive();
  }
}
