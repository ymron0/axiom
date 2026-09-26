import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Builds a ledger entry from user-entered transaction value.
///
/// This service owns conversion from the transaction representation to:
///
/// - the affected account's denomination asset; and
/// - the configured valuation currency.
///
/// ## Semantics
///
/// Presentation code supplies the financial movement as entered by the user.
/// Account and valuation representations are resolved here rather than in the
/// widget layer.
///
/// ## Contract
///
/// Expected lookup and rate failures remain typed [BaseFailure] values.
///
/// Programmer errors such as attaching a percentage expression to a primary
/// entry are rejected with [ArgumentError].
final class BuildTransactionLedgerEntryService {
  final GetAccountByIdUseCase _getAccountById;
  final GetValuationCurrencyService _getValuationCurrency;
  final ValueAssetAmountsService _valueAssetAmounts;

  /// Creates the ledger-entry builder.
  const BuildTransactionLedgerEntryService({
    required GetAccountByIdUseCase getAccountById,
    required GetValuationCurrencyService getValuationCurrency,
    required ValueAssetAmountsService valueAssetAmounts,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency,
       _valueAssetAmounts = // ignore: prefer_initializing_formals
           valueAssetAmounts;

  /// Builds one ledger entry.
  Future<Result<LedgerEntry, BaseFailure>> call({
    required AccountId accountId,
    required AssetAmount transactionAmount,
    required DateTime effectiveAt,
    LedgerEntryRole role = LedgerEntryRole.primary,
    Decimal? feePercentage,
  }) async {
    if (role != LedgerEntryRole.fee && feePercentage != null) {
      throw ArgumentError.value(
        feePercentage,
        'feePercentage',
        'Only fee ledger entries may have a percentage expression.',
      );
    }

    final accountResult = await _getAccountById(accountId);

    if (accountResult case final Failure failure) {
      return failure;
    }

    final account = accountResult.valueOrNull;

    if (account == null) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${accountId.value}',
      );
    }

    final valuationCurrencyResult = await _getValuationCurrency();

    if (valuationCurrencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = valuationCurrencyResult.valueOrNull!;

    final accountAmountResult = await _valueAssetAmounts(
      amounts: [transactionAmount],
      targetAssetId: account.denominationAssetId,
      at: effectiveAt,
    );

    if (accountAmountResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationAmountResult = await _valueAssetAmounts(
      amounts: [transactionAmount],
      targetAssetId: valuationCurrency.id,
      at: effectiveAt,
    );

    if (valuationAmountResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final accountAmount = accountAmountResult.valueOrNull!;
    final valuationAmount = valuationAmountResult.valueOrNull!;

    if (role == LedgerEntryRole.primary) {
      return Success(
        LedgerEntry(
          accountId: accountId,
          transactionAmount: transactionAmount,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
          role: LedgerEntryRole.primary,
        ),
      );
    }

    if (feePercentage != null) {
      return Success(
        LedgerEntry.percentageFee(
          accountId: accountId,
          transactionAmount: transactionAmount,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
          percentage: feePercentage,
        ),
      );
    }

    return Success(
      LedgerEntry.assetAmountFee(
        accountId: accountId,
        transactionAmount: transactionAmount,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      ),
    );
  }
}
