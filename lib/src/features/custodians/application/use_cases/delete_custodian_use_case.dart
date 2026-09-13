import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Physically deletes a custodian and returns its deleted snapshot.
final class DeleteCustodianUseCase {
  /// Creates a use case backed by [repository].
  DeleteCustodianUseCase(this._repository);

  final CustodianRepository _repository;

  /// Deletes the custodian identified by [id].
  ///
  /// Returns the caller-retained deleted snapshot or a [CustodianFailure].
  Future<Result<Custodian, CustodianFailure>> call(CustodianId id) {
    return _repository.delete(id);
  }
}
