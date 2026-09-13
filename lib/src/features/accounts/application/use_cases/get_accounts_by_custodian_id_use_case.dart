import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Retrieves active persisted accounts belonging to one custodian.
class GetAccountsByCustodianIdUseCase {
  /// Creates a use case backed by [repository].
  GetAccountsByCustodianIdUseCase(this._repository);

  final AccountRepository _repository;

  /// Returns all active persisted accounts belonging to [custodianId].
  ///
  /// Returns an empty list when the custodian has no accounts, or an
  /// [AccountFailure] when retrieval fails.
  Future<Result<List<Account>, AccountFailure>> call(CustodianId custodianId) {
    return _repository.getByCustodianId(custodianId);
  }
}
