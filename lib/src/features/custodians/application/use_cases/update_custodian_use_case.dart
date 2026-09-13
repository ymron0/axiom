import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Replaces one active persisted custodian snapshot.
final class UpdateCustodianUseCase {
  /// Creates a use case backed by [repository].
  UpdateCustodianUseCase(this._repository);

  final CustodianRepository _repository;

  /// Replaces the persisted snapshot for [custodian].
  ///
  /// Returns a [CustodianFailure] when the custodian is deleted or absent from
  /// persistence.
  Future<Result<void, CustodianFailure>> call(Custodian custodian) {
    return _repository.update(custodian);
  }
}
