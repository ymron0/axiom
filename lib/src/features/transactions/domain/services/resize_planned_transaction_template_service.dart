import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';

/// Resizes the primary monetary value of a planned transaction template.
///
/// This service is used when an amount-terminated recurrence uses exact-target
/// completion and its final occurrence must be smaller than its normal
/// occurrence.
///
/// ## Semantics
///
/// The primary transaction amount becomes [primaryAmount].
///
/// The primary account and valuation representations are scaled
/// proportionally, preserving the conversion ratios represented by the
/// transaction-series template.
///
/// Allocation splits are also resized proportionally. The final split receives
/// any decimal remainder so the resulting collection reconciles exactly with
/// the resized primary amount.
///
/// Non-primary ledger entries are preserved unchanged. A fee, for example,
/// does not automatically shrink merely because the recurrence's final primary
/// installment is smaller.
///
/// ## Unknown amounts
///
/// Unknown account or valuation representations are preserved. If that leaves
/// the resulting transaction financially invalid, normal transaction
/// instantiation translates the aggregate violation into its existing typed
/// failure.
///
/// ## Preconditions
///
/// The template must contain exactly one primary ledger entry whose transaction
/// amount:
///
/// - is known;
/// - is greater than zero; and
/// - uses the same asset and direction as [primaryAmount].
final class ResizePlannedTransactionTemplateService {
  /// Creates a stateless template resizing service.
  const ResizePlannedTransactionTemplateService();

  /// Returns [template] resized to [primaryAmount].
  TransactionTemplate call({
    required TransactionTemplate template,
    required AssetAmount primaryAmount,
  }) {
    final primaryEntries = template.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    if (primaryEntries.length != 1) {
      throw ArgumentError.value(
        template,
        'template',
        'Exact-target resizing requires exactly one primary ledger entry.',
      );
    }

    final originalPrimaryEntry = primaryEntries.single;
    final originalPrimaryAmount = originalPrimaryEntry.transactionAmount;

    if (originalPrimaryAmount.isUnknownAmount) {
      throw ArgumentError.value(
        template,
        'template',
        'Exact-target resizing requires a known primary transaction amount.',
      );
    }

    if (originalPrimaryAmount.amount <= Decimal.zero) {
      throw ArgumentError.value(
        template,
        'template',
        'Exact-target resizing requires a positive primary transaction amount.',
      );
    }

    if (primaryAmount.isUnknownAmount) {
      throw ArgumentError.value(
        primaryAmount,
        'primaryAmount',
        'The resized primary amount must be known.',
      );
    }

    if (primaryAmount.assetId != originalPrimaryAmount.assetId) {
      throw ArgumentError.value(
        primaryAmount,
        'primaryAmount',
        'The resized primary amount must use the original primary asset.',
      );
    }

    if (primaryAmount.direction != originalPrimaryAmount.direction) {
      throw ArgumentError.value(
        primaryAmount,
        'primaryAmount',
        'The resized primary amount must preserve the original direction.',
      );
    }

    if (primaryAmount.amount == originalPrimaryAmount.amount) {
      return template;
    }

    final resizedAccountAmount = _scaleAmount(
      amount: originalPrimaryEntry.accountAmount,
      sourcePrimaryMagnitude: originalPrimaryAmount.amount,
      targetPrimaryMagnitude: primaryAmount.amount,
    );

    final resizedValuationAmount = _scaleAmount(
      amount: originalPrimaryEntry.valuationAmount,
      sourcePrimaryMagnitude: originalPrimaryAmount.amount,
      targetPrimaryMagnitude: primaryAmount.amount,
    );

    final resizedPrimaryEntry = LedgerEntry(
      accountId: originalPrimaryEntry.accountId,
      transactionAmount: primaryAmount,
      accountAmount: resizedAccountAmount,
      valuationAmount: resizedValuationAmount,
      role: originalPrimaryEntry.role,
    );

    final resizedLedgerEntries = <LedgerEntry>[
      for (final entry in template.ledgerEntries)
        if (identical(entry, originalPrimaryEntry))
          resizedPrimaryEntry
        else
          entry,
    ];

    final resizedSplits = _resizeSplits(
      template.splits,
      transactionTotal: primaryAmount,
      valuationTotal: resizedValuationAmount,
    );

    return TransactionTemplate(
      kind: template.kind,
      merchantId: template.merchantId,
      description: template.description,
      note: template.note,
      splits: resizedSplits,
      ledgerEntries: resizedLedgerEntries,
    );
  }

  static AssetAmount _scaleAmount({
    required AssetAmount amount,
    required Decimal sourcePrimaryMagnitude,
    required Decimal targetPrimaryMagnitude,
  }) {
    if (amount.isUnknownAmount) {
      return amount;
    }

    final scaledMagnitude =
        ((amount.amount * targetPrimaryMagnitude) / sourcePrimaryMagnitude)
            .toDecimal(scaleOnInfinitePrecision: 18);

    return AssetAmount(
      assetId: amount.assetId,
      amount: scaledMagnitude,
      direction: amount.direction,
    );
  }

  static List<TransactionSplit> _resizeSplits(
    List<TransactionSplit> splits, {
    required AssetAmount transactionTotal,
    required AssetAmount valuationTotal,
  }) {
    if (splits.isEmpty) {
      return const [];
    }

    final transactionParts = _redistribute(
      splits.map((split) => split.transactionAmount).toList(growable: false),
      targetTotal: transactionTotal,
    );

    final valuationParts = _redistribute(
      splits.map((split) => split.valuationAmount).toList(growable: false),
      targetTotal: valuationTotal,
    );

    return List<TransactionSplit>.unmodifiable([
      for (var index = 0; index < splits.length; index++)
        TransactionSplit(
          transactionAmount: transactionParts[index],
          valuationAmount: valuationParts[index],
          categoryId: splits[index].categoryId,
          jarId: splits[index].jarId,
        ),
    ]);
  }

  static List<AssetAmount> _redistribute(
    List<AssetAmount> originalParts, {
    required AssetAmount targetTotal,
  }) {
    if (originalParts.isEmpty) {
      return const [];
    }

    if (targetTotal.isUnknownAmount ||
        originalParts.any((amount) => amount.isUnknownAmount)) {
      return List<AssetAmount>.unmodifiable(originalParts);
    }

    final compatible = originalParts.every(
      (amount) =>
          amount.assetId == targetTotal.assetId &&
          amount.direction == targetTotal.direction,
    );

    if (!compatible) {
      // Preserve the invalid structure so normal Transaction aggregate
      // validation can translate it into the established typed failure.
      return List<AssetAmount>.unmodifiable(originalParts);
    }

    final originalTotal = originalParts.fold<Decimal>(
      Decimal.zero,
      (total, amount) => total + amount.amount,
    );

    if (originalTotal <= Decimal.zero) {
      return List<AssetAmount>.unmodifiable(originalParts);
    }

    var remaining = targetTotal.amount;
    final result = <AssetAmount>[];

    for (var index = 0; index < originalParts.length; index++) {
      final originalPart = originalParts[index];
      final isLast = index == originalParts.length - 1;

      final magnitude = isLast
          ? remaining
          : _boundedScaledMagnitude(
              originalMagnitude: originalPart.amount,
              originalTotal: originalTotal,
              targetTotal: targetTotal.amount,
              remaining: remaining,
            );

      result.add(
        AssetAmount(
          assetId: originalPart.assetId,
          amount: magnitude,
          direction: originalPart.direction,
        ),
      );

      remaining -= magnitude;
    }

    return List<AssetAmount>.unmodifiable(result);
  }

  static Decimal _boundedScaledMagnitude({
    required Decimal originalMagnitude,
    required Decimal originalTotal,
    required Decimal targetTotal,
    required Decimal remaining,
  }) {
    final proposed = ((originalMagnitude * targetTotal) / originalTotal)
        .toDecimal(scaleOnInfinitePrecision: 18);

    if (proposed > remaining) {
      return remaining;
    }

    return proposed;
  }
}
