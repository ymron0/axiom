import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:decimal/decimal.dart';

/// Derives the current net worth across all active accounts.
///
/// This service coordinates Accounts, Settings, and asset valuation.
///
/// ## Account semantics
///
/// Net worth is based on the current balances of all active accounts returned
/// by [GetAccountsUseCase].
///
/// Individual account balances are delegated to [GetAccountBalanceService].
/// This service therefore does not inspect transaction ledger entries or
/// duplicate account-balance arithmetic.
///
/// Soft-deleted accounts are excluded by the Accounts feature because
/// [GetAccountsUseCase] returns active accounts only.
///
/// ## Currency semantics
///
/// Account balances remain in their persisted denomination asset until all
/// accounts using the same asset have been combined.
///
/// For example, two EUR accounts with balances `100` and `-25` first become one
/// EUR balance of `75`. Only that EUR 75 aggregate is then valued into the
/// configured valuation currency.
///
/// Balances belonging to different assets are never added together before
/// valuation.
///
/// This has several useful properties:
///
/// - one valuation is required per distinct non-zero foreign asset rather than
///   per account;
/// - positive and negative balances in the same asset are netted before
///   conversion;
/// - a foreign-asset aggregate of zero requires no exchange rate; and
/// - conversion occurs before values from different assets are combined.
///
/// Accounts already denominated in the configured valuation currency bypass
/// [AssetValuationService] because valuation is an identity operation.
///
/// ## Sign semantics
///
/// [GetAccountBalanceService] returns signed [Decimal] balances.
///
/// Positive balances increase net worth and negative balances reduce it.
///
/// The returned [AssetAmount] represents the signed net position:
///
/// - positive net worth is returned as an incoming amount;
/// - negative net worth is returned as an outgoing amount; and
/// - zero net worth is canonically returned as incoming zero.
///
/// ## Valuation time
///
/// One UTC instant is obtained from [Clock] after account balances have been
/// resolved. Every required asset valuation receives that same instant.
///
/// Consequently, different foreign assets cannot accidentally be valued at
/// slightly different clock instants during one net-worth calculation.
///
/// This service derives current net worth. The valuation instant controls rate
/// selection; it does not turn the current account-balance lookup into a
/// historical balance query.
///
/// ## Precision
///
/// All arithmetic uses [Decimal]. No conversion through `double`, implicit
/// rounding, display formatting, or asset-specific decimal-place truncation
/// occurs here.
///
/// ## Failure semantics
///
/// Expected failures from Settings, Accounts, account-balance calculation, or
/// asset valuation are propagated unchanged.
///
/// [SettingsNotInitializedFailure] is returned when application settings do not
/// exist.
///
/// The configured valuation currency is resolved before valuation begins. If a
/// downstream valuation unexpectedly returns a different asset, an
/// [InvalidValuationCurrencyFailure] is returned rather than combining values
/// expressed in different currencies.
///
/// Processing stops at the first failure. Partial net worth values are never
/// returned.
final class GetNetWorthService {
  final GetSettingsUseCase _getSettings;
  final GetAccountsUseCase _getAccounts;
  final GetAccountBalanceService _getAccountBalance;
  final AssetValuationService _assetValuation;
  final Clock _clock;

  /// Creates the net-worth service.
  const GetNetWorthService({
    required GetSettingsUseCase getSettings,
    required GetAccountsUseCase getAccounts,
    required GetAccountBalanceService getAccountBalance,
    required AssetValuationService assetValuation,
    required Clock clock,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getAccounts = getAccounts, // ignore: prefer_initializing_formals
       _getAccountBalance = // ignore: prefer_initializing_formals
           getAccountBalance,
       _assetValuation = // ignore: prefer_initializing_formals
           assetValuation,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Returns the current net worth in the configured valuation currency.
  Future<Result<AssetAmount, BaseFailure>> call() async {
    final settingsResult = await _getSettings();

    if (settingsResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final settings = settingsResult.valueOrNull;

    if (settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    final accountsResult = await _getAccounts();

    if (accountsResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final valuationCurrencyId = settings.valuationCurrencyId;
    final balancesByAsset = <AssetId, Decimal>{};

    for (final account in accountsResult.valueOrNull!) {
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

    final valuationAt = _clock.nowUtc;
    var signedNetWorth = Decimal.zero;

    for (final entry in balancesByAsset.entries) {
      final sourceAssetId = entry.key;
      final signedBalance = entry.value;

      if (signedBalance == Decimal.zero) {
        continue;
      }

      if (sourceAssetId == valuationCurrencyId) {
        signedNetWorth += signedBalance;
        continue;
      }

      final sourceAmount = _fromSignedAmount(
        assetId: sourceAssetId,
        signedAmount: signedBalance,
      );

      final valuationResult = await _assetValuation(
        amount: sourceAmount,
        at: valuationAt,
      );

      if (valuationResult case final Failure<BaseFailure> failure) {
        return failure;
      }

      final valuation = valuationResult.valueOrNull!;

      if (valuation.assetId != valuationCurrencyId) {
        return InvalidValuationCurrencyFailure(
          message:
              'Net worth valuation returned asset '
              '${valuation.assetId.value}, but the configured valuation '
              'currency is ${valuationCurrencyId.value}.',
        );
      }

      signedNetWorth += _toSignedAmount(valuation);
    }

    return Success(
      _fromSignedAmount(
        assetId: valuationCurrencyId,
        signedAmount: signedNetWorth,
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

  Decimal _toSignedAmount(AssetAmount amount) {
    return amount.isIncoming ? amount.amount : -amount.amount;
  }
}
