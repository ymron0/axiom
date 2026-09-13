import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/delete_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_in_use_failure.dart';

/// Deletes a custodian when no persisted account references it.
///
/// Returns [CustodianInUseFailure] without deleting the custodian when at least
/// one associated account exists. Lookup and deletion failures are preserved.
final class DeleteCustodianService {
  /// Creates a custodian deletion service.
  const DeleteCustodianService({
    required GetAccountsByCustodianIdUseCase getAccounts,
    required DeleteCustodianUseCase deleteCustodian,
  }) : _getAccounts = getAccounts, // ignore: prefer_initializing_formals
       _deleteCustodian = deleteCustodian; // ignore: prefer_initializing_formals

  final GetAccountsByCustodianIdUseCase _getAccounts;
  final DeleteCustodianUseCase _deleteCustodian;

  /// Deletes the custodian identified by [custodianId] when it is not in use.
  Future<Result<Custodian, BaseFailure>> call(CustodianId custodianId) async {
    final accountsResult = await _getAccounts(custodianId);

    return accountsResult.when<Future<Result<Custodian, BaseFailure>>>(
      success: (accounts) async {
        if (accounts.isNotEmpty) {
          return CustodianInUseFailure(
            message: 'Custodian is referenced by an account: $custodianId',
          );
        }

        return _deleteCustodian(custodianId);
      },
      failure: (failure) async => failure,
    );
  }
}
