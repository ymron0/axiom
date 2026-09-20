import 'package:axiom/src/application/failures/account_valuation_unavailable_failure.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:decimal/decimal.dart';

/// Derives one account's current balance and fiat valuation.
///
/// The account amount remains expressed in the account's denomination asset,
/// which may be a Currency, CryptoAsset, StockAsset, or CommodityAsset.
///
/// The valuation amount is always expressed in the configured valuation
/// Currency because conversion is delegated to [AssetValuationService].
final class GetAccountValuationService {
  final GetAccountByIdUseCase _getAccountById;

  final GetAccountBalanceService _getAccountBalance;
  final AssetValuationService _assetValuation;
  final Clock _clock;
  /// Creates the account valuation workflow.
  const GetAccountValuationService({
    required GetAccountByIdUseCase getAccountById,
    required GetAccountBalanceService getAccountBalance,
    required AssetValuationService assetValuation,
    required Clock clock,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getAccountBalance = // ignore: prefer_initializing_formals
           getAccountBalance,
       _assetValuation = assetValuation, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Derives the current [AccountValuation] for [accountId].
  Future<Result<AccountValuation, BaseFailure>> call(
    AccountId accountId,
  ) async {
    final accountResult = await _getAccountById(accountId);

    if (accountResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final account = accountResult.valueOrNull;

    if (account == null) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${accountId.value}',
      );
    }

    final balanceResult = await _getAccountBalance(account.id);

    if (balanceResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final signedBalance = balanceResult.valueOrNull!;

    final accountAmount = _fromSignedAmount(
      assetId: account.denominationAssetId,
      signedAmount: signedBalance,
    );

    final valuationResult = await _assetValuation(
      amount: accountAmount,
      at: _clock.nowUtc,
    );

    if (valuationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationAmount = valuationResult.valueOrNull!;

    if (valuationAmount.isUnknownAmount) {
      return AccountValuationUnavailableFailure(
        message:
            'Account ${account.id.value} cannot currently be valued in the '
            'configured valuation currency.',
      );
    }

    return Success(
      AccountValuation(
        accountId: account.id,
        custodianId: account.custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      ),
    );
  }

  AssetAmount _fromSignedAmount({
    required AssetId assetId,
    required Decimal signedAmount,
  }) {
    if (signedAmount < Decimal.zero) {
      return AssetAmount.outgoing(assetId: assetId, amount: signedAmount.abs());
    }

    return AssetAmount.incoming(assetId: assetId, amount: signedAmount);
  }
}
