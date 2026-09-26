import 'package:axiom/src/application/di/services/get_account_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_active_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/custodians/di/get_active_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_state.g.dart';

/// Data required to render account valuation consistently.
final class AccountValuationPresentationData {
  /// Creates account valuation presentation data.
  const AccountValuationPresentationData({
    required this.valuation,
    required this.denominationAsset,
    required this.valuationCurrency,
  });

  final AccountValuation valuation;
  final Asset denominationAsset;
  final Currency valuationCurrency;
}

/// Supporting values required by account create/edit forms.
final class AccountFormOptions {
  /// Creates account form options.
  const AccountFormOptions({
    required this.custodians,
    required this.assets,
    required this.nextSortOrder,
  });

  final List<Custodian> custodians;
  final List<Asset> assets;
  final int nextSortOrder;
}

/// Loads active accounts for the overview.
@riverpod
Future<Result<List<Account>, AccountFailure>> accounts(Ref ref) async {
  final result = await ref.watch(getActiveAccountsUseCaseProvider)();

  return result.when<Result<List<Account>, AccountFailure>>(
    success: (accounts) {
      final sorted = List<Account>.of(accounts)
        ..sort((left, right) {
          final order = left.sortOrder.compareTo(right.sortOrder);

          if (order != 0) {
            return order;
          }

          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });

      return Success(sorted);
    },
    failure: (failure) => failure,
  );
}

/// Loads one account by ID.
@riverpod
Future<Result<Account?, AccountFailure>> account(Ref ref, AccountId accountId) {
  return ref.watch(getAccountByIdUseCaseProvider)(accountId);
}

/// Loads the custodian associated with an account.
@riverpod
Future<Result<Custodian?, CustodianFailure>> accountCustodian(
  Ref ref,
  CustodianId custodianId,
) {
  return ref.watch(getCustodianByIdUseCaseProvider)(custodianId);
}

/// Loads complete current account valuation presentation data.
///
/// Financial calculations remain owned by [GetAccountValuationService].
@riverpod
Future<Result<AccountValuationPresentationData, BaseFailure>>
accountValuationPresentation(Ref ref, AccountId accountId) async {
  final accountResult = await ref.watch(getAccountByIdUseCaseProvider)(
    accountId,
  );

  if (accountResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final loadedAccount = accountResult.valueOrNull;

  if (loadedAccount == null) {
    return AccountNotFoundFailure(
      message: 'Account ID was not found: ${accountId.value}',
    );
  }

  final valuationResult = await ref.watch(getAccountValuationServiceProvider)(
    accountId,
  );

  if (valuationResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final denominationResult = await ref.watch(getAssetByIdUseCaseProvider)(
    loadedAccount.denominationAssetId,
  );

  if (denominationResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final denominationAsset = denominationResult.valueOrNull;

  if (denominationAsset == null) {
    return AssetNotFoundFailure(
      message:
          'Account denomination asset was not found: '
          '${loadedAccount.denominationAssetId.value}',
    );
  }

  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    AccountValuationPresentationData(
      valuation: valuationResult.valueOrNull!,
      denominationAsset: denominationAsset,
      valuationCurrency: currencyResult.valueOrNull!,
    ),
  );
}

/// Loads supporting values for account creation and editing.
///
/// [includedCustodianId] ensures an archived custodian already assigned to an
/// edited account remains selectable.
@riverpod
Future<Result<AccountFormOptions, BaseFailure>> accountFormOptions(
  Ref ref,
  CustodianId? includedCustodianId,
) async {
  final custodiansResult = await ref.watch(
    getActiveCustodiansUseCaseProvider,
  )();

  if (custodiansResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final custodians = List<Custodian>.of(custodiansResult.valueOrNull!);

  if (includedCustodianId != null &&
      !custodians.any((custodian) => custodian.id == includedCustodianId)) {
    final includedResult = await ref.watch(getCustodianByIdUseCaseProvider)(
      includedCustodianId,
    );

    if (includedResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final included = includedResult.valueOrNull;

    if (included != null) {
      custodians.add(included);
    }
  }

  custodians.sort((left, right) {
    final order = left.sortOrder.compareTo(right.sortOrder);

    if (order != 0) {
      return order;
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });

  final assetsResult = await ref.watch(getAssetUseCaseProvider)();

  if (assetsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final assets = List<Asset>.of(assetsResult.valueOrNull!)
    ..sort((left, right) => left.code.value.compareTo(right.code.value));

  final accountsResult = await ref.watch(getAccountsUseCaseProvider)();

  if (accountsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  var nextSortOrder = 0;

  for (final account in accountsResult.valueOrNull!) {
    if (account.sortOrder >= nextSortOrder) {
      nextSortOrder = account.sortOrder + 1;
    }
  }

  return Success(
    AccountFormOptions(
      custodians: List.unmodifiable(custodians),
      assets: List.unmodifiable(assets),
      nextSortOrder: nextSortOrder,
    ),
  );
}
