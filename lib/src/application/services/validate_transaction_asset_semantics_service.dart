import 'package:axiom/src/application/failures/invalid_payment_asset_failure.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';

/// Validates transaction asset relationships requiring application context.
///
/// The Transaction aggregate contains typed Asset IDs but cannot know which
/// concrete Asset instances those IDs represent.
///
/// This service therefore validates:
///
/// - every referenced asset exists;
/// - valuation amounts use the configured fiat valuation Currency; and
/// - expense/income payment amounts use payment-enabled assets.
///
/// Internal transfers and balance corrections are deliberately not subject to
/// payment eligibility. A StockAsset or non-payment-enabled CryptoAsset may
/// therefore still be moved between accounts or corrected.
final class ValidateTransactionAssetSemanticsService {
  final GetAssetsByIdsUseCase _getAssetsByIds;

  final GetValuationCurrencyService _getValuationCurrency;
  /// Creates the validator.
  const ValidateTransactionAssetSemanticsService({
    required GetAssetsByIdsUseCase getAssetsByIds,
    required GetValuationCurrencyService getValuationCurrency,
  }) : _getAssetsByIds = getAssetsByIds, // ignore: prefer_initializing_formals
       _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency;

  /// Validates all cross-feature asset semantics for [transaction].
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final referencedIds = _collectReferencedAssetIds(transaction);

    final assetsResult = await _getAssetsByIds(referencedIds);

    if (assetsResult case final Failure failure) {
      return failure;
    }

    final lookup = assetsResult.valueOrNull!;

    if (lookup.missing.isNotEmpty) {
      return ReferencedAssetNotFoundFailure(
        message:
            'Transaction references missing asset '
            '${lookup.missing.first.value}.',
      );
    }

    final assetsById = <AssetId, Asset>{
      for (final asset in lookup.found) asset.id: asset,
    };

    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = currencyResult.valueOrNull!;

    final valuationResult = _validateValuationAmounts(
      transaction: transaction,
      valuationCurrencyId: valuationCurrency.id,
    );

    if (valuationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    if (_requiresPaymentAsset(transaction.kind)) {
      final paymentResult = _validatePaymentAssets(
        transaction: transaction,
        assetsById: assetsById,
      );

      if (paymentResult case final Failure<BaseFailure> failure) {
        return failure;
      }
    }

    return const Success(null);
  }

  /// Collects every Asset ID referenced by monetary transaction state.
  List<AssetId> _collectReferencedAssetIds(Transaction transaction) {
    final ids = <AssetId>{};

    for (final entry in transaction.ledgerEntries) {
      ids
        ..add(entry.transactionAmount.assetId)
        ..add(entry.accountAmount.assetId)
        ..add(entry.valuationAmount.assetId);
    }

    for (final split in transaction.splits) {
      ids
        ..add(split.transactionAmount.assetId)
        ..add(split.valuationAmount.assetId);
    }

    return ids.toList(growable: false);
  }

  bool _requiresPaymentAsset(TransactionKind kind) {
    return kind == TransactionKind.expense || kind == TransactionKind.income;
  }

  Result<void, BaseFailure> _validatePaymentAssets({
    required Transaction transaction,
    required Map<AssetId, Asset> assetsById,
  }) {
    final paymentAssetIds = {
      for (final entry in transaction.ledgerEntries)
        entry.transactionAmount.assetId,
    };

    for (final assetId in paymentAssetIds) {
      final asset = assetsById[assetId];

      // Missing assets have already been rejected by the batch lookup.
      if (asset == null) {
        return ReferencedAssetNotFoundFailure(
          message: 'Payment asset was not found: ${assetId.value}.',
        );
      }

      if (!asset.paymentEnabled) {
        return InvalidPaymentAssetFailure(
          message: 'Asset ${asset.code.value} is not enabled for payments.',
        );
      }
    }

    return const Success(null);
  }

  Result<void, BaseFailure> _validateValuationAmounts({
    required Transaction transaction,
    required AssetId valuationCurrencyId,
  }) {
    for (final entry in transaction.ledgerEntries) {
      if (entry.valuationAmount.assetId != valuationCurrencyId) {
        return InvalidValuationCurrencyFailure(
          message:
              'Ledger valuation amount must use valuation currency '
              '${valuationCurrencyId.value}; received '
              '${entry.valuationAmount.assetId.value}.',
        );
      }
    }

    for (final split in transaction.splits) {
      if (split.valuationAmount.assetId != valuationCurrencyId) {
        return InvalidValuationCurrencyFailure(
          message:
              'Transaction split valuation amount must use valuation currency '
              '${valuationCurrencyId.value}; received '
              '${split.valuationAmount.assetId.value}.',
        );
      }
    }

    return const Success(null);
  }
}
