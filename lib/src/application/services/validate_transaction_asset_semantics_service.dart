import 'package:axiom/src/application/failures/invalid_payment_asset_failure.dart';
import 'package:axiom/src/application/failures/invalid_trade_asset_failure.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';

/// Validates transaction asset relationships requiring application context.
///
/// This service validates:
///
/// - every referenced asset exists;
/// - valuation amounts use the configured valuation currency;
/// - expense/income primary payment amounts use payment-enabled assets;
/// - fees may use any existing asset;
/// - buys acquire a non-cash asset using a payment-enabled settlement asset;
/// - sells dispose of a non-cash asset for a payment-enabled settlement asset.
///
/// Dividend and reward transactions deliberately accept any received asset.
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

    if (_isTrade(transaction.kind)) {
      final tradeResult = _validateTradeAssets(
        transaction: transaction,
        assetsById: assetsById,
      );

      if (tradeResult case final Failure<BaseFailure> failure) {
        return failure;
      }
    }

    return const Success(null);
  }

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

  bool _isTrade(TransactionKind kind) {
    return kind == TransactionKind.buy || kind == TransactionKind.sell;
  }

  /// Validates ordinary payment transactions.
  ///
  /// Only primary entries are checked. Fee entries are deliberately excluded,
  /// allowing fees to be charged in any supported asset.
  Result<void, BaseFailure> _validatePaymentAssets({
    required Transaction transaction,
    required Map<AssetId, Asset> assetsById,
  }) {
    final paymentAssetIds = {
      for (final entry in transaction.ledgerEntries)
        if (entry.role == LedgerEntryRole.primary)
          entry.transactionAmount.assetId,
    };

    for (final assetId in paymentAssetIds) {
      final asset = assetsById[assetId];

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

  Result<void, BaseFailure> _validateTradeAssets({
    required Transaction transaction,
    required Map<AssetId, Asset> assetsById,
  }) {
    final primaryEntries = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    // Transaction aggregate validation guarantees two opposing primary entries.
    final tradedEntry = switch (transaction.kind) {
      TransactionKind.buy => primaryEntries.singleWhere(
        (entry) => entry.transactionAmount.isIncoming,
      ),
      TransactionKind.sell => primaryEntries.singleWhere(
        (entry) => entry.transactionAmount.isOutgoing,
      ),
      _ => throw StateError(
        'Trade validation requires a buy or sell transaction.',
      ),
    };

    final settlementEntry = switch (transaction.kind) {
      TransactionKind.buy => primaryEntries.singleWhere(
        (entry) => entry.transactionAmount.isOutgoing,
      ),
      TransactionKind.sell => primaryEntries.singleWhere(
        (entry) => entry.transactionAmount.isIncoming,
      ),
      _ => throw StateError(
        'Trade validation requires a buy or sell transaction.',
      ),
    };

    return _validateTradePair(
      tradedEntry: tradedEntry,
      settlementEntry: settlementEntry,
      assetsById: assetsById,
    );
  }

  Result<void, BaseFailure> _validateTradePair({
    required LedgerEntry tradedEntry,
    required LedgerEntry settlementEntry,
    required Map<AssetId, Asset> assetsById,
  }) {
    final tradedAssetId = tradedEntry.transactionAmount.assetId;
    final settlementAssetId = settlementEntry.transactionAmount.assetId;

    final tradedAsset = assetsById[tradedAssetId];
    final settlementAsset = assetsById[settlementAssetId];

    if (tradedAsset == null) {
      return ReferencedAssetNotFoundFailure(
        message: 'Traded asset was not found: ${tradedAssetId.value}.',
      );
    }

    if (settlementAsset == null) {
      return ReferencedAssetNotFoundFailure(
        message: 'Settlement asset was not found: ${settlementAssetId.value}.',
      );
    }

    if (tradedAssetId == settlementAssetId) {
      return InvalidTradeAssetFailure(
        message:
            'A buy or sell transaction cannot trade an asset against itself: '
            '${tradedAsset.code.value}.',
      );
    }

    if (tradedAsset is Currency) {
      return InvalidTradeAssetFailure(
        message:
            'Buy and sell transactions require a non-cash traded asset; '
            '${tradedAsset.code.value} is a currency.',
      );
    }

    if (!settlementAsset.paymentEnabled) {
      return InvalidPaymentAssetFailure(
        message:
            'Trade settlement asset ${settlementAsset.code.value} is not '
            'enabled for payments.',
      );
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
