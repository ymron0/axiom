import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Retrieves an active persisted custodian by identifier.
final class GetCustodianByIdUseCase {
  /// Creates a use case backed by [repository].
  GetCustodianByIdUseCase(this._repository);

  final CustodianRepository _repository;

  /// Returns the active custodian matching [id], or `null` when absent.
  Future<Result<Custodian?, CustodianFailure>> call(CustodianId id) {
    return _repository.getById(id);
  }
}
