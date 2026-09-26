import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/presentation/formatting/asset_amount_formatter.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:flutter/material.dart';

/// Human-readable transaction-kind label.
String transactionKindLabel(TransactionKind kind) {
  return switch (kind) {
    TransactionKind.expense => 'Expense',
    TransactionKind.income => 'Income',
    TransactionKind.transfer => 'Transfer',
    TransactionKind.balanceCorrection => 'Balance correction',
    TransactionKind.buy => 'Buy',
    TransactionKind.sell => 'Sell',
    TransactionKind.dividend => 'Dividend',
    TransactionKind.reward => 'Reward',
  };
}

/// Material icon for a transaction kind.
IconData transactionKindIcon(TransactionKind kind) {
  return switch (kind) {
    TransactionKind.expense => Icons.arrow_upward_rounded,
    TransactionKind.income => Icons.arrow_downward_rounded,
    TransactionKind.transfer => Icons.swap_horiz_rounded,
    TransactionKind.balanceCorrection => Icons.tune_rounded,
    TransactionKind.buy => Icons.add_chart_rounded,
    TransactionKind.sell => Icons.sell_rounded,
    TransactionKind.dividend => Icons.payments_rounded,
    TransactionKind.reward => Icons.redeem_rounded,
  };
}

/// User-facing counterparty/fallback label.
String transactionCounterparty(
  Transaction transaction,
  TransactionActivityData data,
) {
  if (!transaction.merchantId.isSelf) {
    return data.source.merchantsById[transaction.merchantId]?.name ??
        'Unknown merchant';
  }

  return switch (transaction.kind) {
    TransactionKind.transfer => 'Transfer',
    TransactionKind.balanceCorrection => 'Balance correction',
    TransactionKind.buy || TransactionKind.sell => 'Trade',
    TransactionKind.dividend => 'Dividend',
    TransactionKind.reward => 'Reward',
    _ => 'No merchant',
  };
}

/// Formats one asset amount using its concrete asset metadata.
String formatTransactionAssetAmount(
  BuildContext context,
  AssetAmount amount,
  TransactionActivityData data, {
  bool includeDirectionSign = true,
}) {
  final asset = data.source.assetsById[amount.assetId];

  if (asset == null) {
    final prefix = includeDirectionSign
        ? amount.isOutgoing
              ? '−'
              : '+'
        : '';

    return '$prefix${amount.amount} ${amount.assetId.value}';
  }

  final formatter = AssetAmountFormatter(
    numbers: PresentationFormatters.of(context).numbers,
  );

  if (asset is Currency) {
    return formatter.currency(
      amount,
      asset,
      includeDirectionSign: includeDirectionSign,
    );
  }

  return formatter.quantity(
    amount,
    asset,
    includeDirectionSign: includeDirectionSign,
  );
}
