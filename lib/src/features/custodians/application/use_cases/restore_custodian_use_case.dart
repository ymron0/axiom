import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Restores a caller-retained, physically deleted custodian snapshot.
final class RestoreCustodianUseCase {
  /// Creates a use case backed by [repository].
  RestoreCustodianUseCase(this._repository);

  final CustodianRepository _repository;

  /// Restores [custodian] as an active persisted custodian.
  ///
  /// Returns a [CustodianFailure] when the snapshot is active already or its
  /// identity is already persisted.
  Future<Result<void, CustodianFailure>> call(Custodian custodian) {
    return _repository.restore(custodian);
  }
}
