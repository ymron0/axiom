import 'package:axiom/src/application/failures/account_valuation_unavailable_failure.dart';
import 'package:axiom/src/application/services/get_account_asset_balances_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';

/// Derives one account's current aggregate value.
///
/// The account may hold several assets.
///
/// Every held asset is valued at the same current instant:
///
/// - once into the account's denomination asset; and
/// - once into the user's configured valuation currency.
///
/// The returned [AccountValuation.accountAmount] therefore represents the
/// complete current account position in the account denomination, rather than
/// merely the historical sum of ledger-entry account amounts.
///
/// [AccountValuation.valuationAmount] represents that same position in the
/// user's configured valuation currency.
final class GetAccountValuationService {
  final GetAccountByIdUseCase _getAccountById;
  final GetAccountAssetBalancesService _getAccountAssetBalances;
  final GetValuationCurrencyService _getValuationCurrency;
  final ValueAssetAmountsService _valueAssetAmounts;
  final Clock _clock;

  /// Creates the account valuation workflow.
  const GetAccountValuationService({
    required GetAccountByIdUseCase getAccountById,
    required GetAccountAssetBalancesService getAccountAssetBalances,
    required GetValuationCurrencyService getValuationCurrency,
    required ValueAssetAmountsService valueAssetAmounts,
    required Clock clock,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getAccountAssetBalances = // ignore: prefer_initializing_formals
           getAccountAssetBalances,
       _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency,
       _valueAssetAmounts = // ignore: prefer_initializing_formals
           valueAssetAmounts,
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

    final balancesResult = await _getAccountAssetBalances(account.id);

    if (balancesResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final assetBalances = balancesResult.valueOrNull!;
    final valuationCurrency = currencyResult.valueOrNull!;
    final valuationAt = _clock.nowUtc;

    final denominationResult = await _valueAssetAmounts(
      amounts: assetBalances,
      targetAssetId: account.denominationAssetId,
      at: valuationAt,
    );

    if (denominationResult case final Failure<BaseFailure> failure) {
      return _translateValuationFailure(
        accountId: account.id,
        failure: failure,
      );
    }

    final accountAmount = denominationResult.valueOrNull!;

    if (valuationCurrency.id == account.denominationAssetId) {
      return Success(
        AccountValuation(
          accountId: account.id,
          custodianId: account.custodianId,
          accountAmount: accountAmount,
          valuationAmount: accountAmount,
        ),
      );
    }

    final valuationResult = await _valueAssetAmounts(
      amounts: assetBalances,
      targetAssetId: valuationCurrency.id,
      at: valuationAt,
    );

    if (valuationResult case final Failure<BaseFailure> failure) {
      return _translateValuationFailure(
        accountId: account.id,
        failure: failure,
      );
    }

    return Success(
      AccountValuation(
        accountId: account.id,
        custodianId: account.custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationResult.valueOrNull!,
      ),
    );
  }

  Result<AccountValuation, BaseFailure> _translateValuationFailure({
    required AccountId accountId,
    required Failure<BaseFailure> failure,
  }) {
    if (failure is RateNotFoundFailure) {
      return AccountValuationUnavailableFailure(
        message:
            'Account ${accountId.value} cannot currently be valued because '
            'a required conversion rate is unavailable.',
      );
    }

    return failure;
  }
}
