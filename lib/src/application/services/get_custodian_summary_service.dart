import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_summary.dart';
import 'package:decimal/decimal.dart';

/// Derives a balance summary for one persisted custodian.
///
/// This service coordinates the Custodians and Accounts features.
///
/// ## Ownership
///
/// Account membership is determined exclusively by
/// [GetAccountsByCustodianIdUseCase]. The service does not infer ownership from
/// transactions or any other relationship.
///
/// Individual account balances are delegated to [GetAccountBalanceService].
/// This service therefore does not duplicate account-balance arithmetic or
/// inspect transaction ledger entries directly.
///
/// ## Currency semantics
///
/// Every account balance is expressed in that account's denomination asset.
///
/// Balances are combined only when accounts share the same denomination asset.
/// Balances belonging to different assets remain separate.
///
/// No exchange-rate lookup or currency conversion occurs here.
///
/// ## Empty custodian semantics
///
/// An existing custodian with no accounts produces a successful
/// [CustodianSummary] with:
///
/// - `accountCount == 0`; and
/// - an empty `balancesByAsset` map.
///
/// ## Failure semantics
///
/// Returns:
///
/// - [CustodianSummary] when all required data can be resolved;
/// - [CustodianNotFoundFailure] when the requested custodian does not exist; or
/// - the original failure returned by any dependent use case or service.
///
/// Processing stops at the first failure. Partial summaries are never returned.
///
/// ## Contract
///
/// This service performs orchestration and aggregation only. It performs no
/// persistence, transaction-level arithmetic, exchange-rate resolution,
/// rounding, or presentation formatting.
final class GetCustodianSummaryService {
  /// Creates a custodian summary service.
  const GetCustodianSummaryService({
    required GetCustodianByIdUseCase getCustodianById,
    required GetAccountsByCustodianIdUseCase getAccountsByCustodianId,
    required GetAccountBalanceService getAccountBalance,
  }) : _getCustodianById = // ignore: prefer_initializing_formals
           getCustodianById,
       _getAccountsByCustodianId = // ignore: prefer_initializing_formals
           getAccountsByCustodianId,
       _getAccountBalance = // ignore: prefer_initializing_formals
           getAccountBalance;

  final GetCustodianByIdUseCase _getCustodianById;
  final GetAccountsByCustodianIdUseCase _getAccountsByCustodianId;
  final GetAccountBalanceService _getAccountBalance;

  /// Derives the current balance summary for [custodianId].
  Future<Result<CustodianSummary, BaseFailure>> call(
    CustodianId custodianId,
  ) async {
    final custodianResult = await _getCustodianById(custodianId);

    if (custodianResult case final Failure<CustodianFailure> failure) {
      return failure;
    }

    final custodian = custodianResult.valueOrNull;

    if (custodian == null) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${custodianId.value}',
      );
    }

    final accountsResult = await _getAccountsByCustodianId(custodian.id);

    if (accountsResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final accounts = accountsResult.valueOrNull!;
    final balancesByAsset = <AssetId, Decimal>{};

    for (final account in accounts) {
      final balanceResult = await _getAccountBalance(account.id);

      if (balanceResult case final Failure<BaseFailure> failure) {
        return failure;
      }

      final balance = balanceResult.valueOrNull!;
      final assetId = account.denominationAssetId;

      balancesByAsset.update(
        assetId,
        (current) => current + balance,
        ifAbsent: () => balance,
      );
    }

    return Success(
      CustodianSummary(
        custodianId: custodian.id,
        accountCount: accounts.length,
        balancesByAsset: balancesByAsset,
      ),
    );
  }
}
