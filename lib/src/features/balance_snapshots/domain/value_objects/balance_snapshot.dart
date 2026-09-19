import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'balance_snapshot.mapper.dart';

/// Immutable daily closing-balance snapshot for an account, custodian, or jar.
///
/// A balance snapshot is derived historical reporting data.
///
/// Transactions, ledger entries, and transaction allocations remain the
/// authoritative financial history. A snapshot may therefore be discarded and
/// rebuilt when historical financial data changes.
///
/// ## Daily semantics
///
/// [snapshotDate] identifies the calendar date whose closing position this
/// snapshot represents.
///
/// Transaction selection and day-boundary interpretation belong to the
/// application workflow that builds snapshots. This value object does not
/// query transactions or interpret time zones.
///
/// ## Capture timestamp
///
/// [capturedAt] identifies when this particular snapshot representation was
/// calculated.
///
/// It is normalized to UTC.
///
/// [capturedAt] is intentionally separate from [snapshotDate]. Historical
/// snapshots may be created, backfilled, or rebuilt long after the date whose
/// financial position they represent.
///
/// ## Asset balances
///
/// [assetBalances] contains the subject's closing positions grouped by asset.
///
/// An account may hold multiple assets even though it has exactly one
/// valuation currency. For example, one account may simultaneously contain:
///
/// - cash;
/// - stocks;
/// - funds;
/// - cryptocurrencies; and
/// - other supported assets.
///
/// A custodian may similarly aggregate assets from several accounts.
///
/// Each asset may occur at most once in [assetBalances].
///
/// [AssetAmount.direction] represents the sign of the closing position:
///
/// - incoming represents a zero or positive position;
/// - outgoing represents a negative position.
///
/// All stored balances must be known. The reserved unknown amount sentinel is
/// not valid historical snapshot data.
///
/// The collection is stored in canonical [AssetId.value] order so logically
/// equivalent asset positions do not depend on input ordering.
///
/// ## Valuation
///
/// [valuationAmount] stores the historical total value of the subject.
///
/// Exactly one valuation currency applies to each snapshot:
///
/// - an account is valued in that account's configured valuation currency;
/// - a custodian is valued in the user's base valuation currency;
/// - a jar is valued in the user's base valuation currency.
///
/// The actual required currency depends on external domain state such as the
/// corresponding Account or Settings. This value object therefore stores the
/// valuation currency through [AssetAmount.assetId] but does not attempt to
/// validate that it is the currently required currency.
///
/// Snapshot-generation workflows must enforce those cross-aggregate rules.
///
/// The historical valuation is stored rather than recalculated during
/// reporting so later exchange-rate changes do not alter previously captured
/// historical values.
///
/// ## Empty positions
///
/// A subject may have no asset balances.
///
/// For example, an account may exist while holding no assets. In that case
/// [valuationAmount] must be zero.
///
/// ## Direct valuation
///
/// When the snapshot contains exactly one asset balance and that asset is also
/// the valuation asset, no conversion exists between the position and its
/// total valuation.
///
/// The amount and direction must therefore be identical.
///
/// ## Categories and budgets
///
/// Categories and budgets are intentionally outside this model.
///
/// Their historical state remains transaction-derived rather than represented
/// through balance snapshots.
///
/// ## Natural identity
///
/// The natural persistence key of a daily snapshot is:
///
/// ```text
/// subject + snapshotDate
/// ```
///
/// Rebuilding the same subject and date replaces the previously derived
/// snapshot rather than creating a second independent domain entity.
@MappableClass()
final class BalanceSnapshot with BalanceSnapshotMappable {
  /// Account, custodian, or jar represented by this snapshot.
  final BalanceSnapshotSubject subject;

  /// Calendar date whose closing financial position is represented.
  final CalendarDate snapshotDate;

  /// UTC instant at which this snapshot representation was calculated.
  final DateTime capturedAt;

  /// Closing position grouped by asset.
  ///
  /// Each asset occurs at most once.
  ///
  /// The collection is immutable and sorted by [AssetId.value].
  final List<AssetAmount> assetBalances;

  /// Total historical value expressed in one valuation currency.
  ///
  /// [AssetAmount.assetId] identifies the currency in which the total valuation
  /// was recorded.
  final AssetAmount valuationAmount;

  /// Creates an immutable daily balance snapshot.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - an asset balance contains an unknown amount;
  /// - [assetBalances] contains the same asset more than once;
  /// - [valuationAmount] contains an unknown amount;
  /// - an empty asset position has a non-zero valuation; or
  /// - the sole asset balance already uses the valuation asset but differs
  ///   from [valuationAmount].
  @MappableConstructor()
  BalanceSnapshot({
    required this.subject,
    required this.snapshotDate,
    required DateTime capturedAt,
    required List<AssetAmount> assetBalances,
    required this.valuationAmount,
  }) : capturedAt = capturedAt.toUtc(),
       assetBalances = _canonicalizeAssetBalances(assetBalances) {
    _validateAssetBalances();
    _validateValuationAmount();
    _validateDirectValuation();
  }

  void _validateAssetBalances() {
    final assetIds = <AssetId>{};

    for (final balance in assetBalances) {
      if (balance.isUnknownAmount) {
        throw ArgumentError.value(
          balance,
          'assetBalances',
          'Balance snapshots cannot contain unknown asset balances.',
        );
      }

      if (!assetIds.add(balance.assetId)) {
        throw ArgumentError.value(
          assetBalances,
          'assetBalances',
          'A balance snapshot may contain at most one balance per asset.',
        );
      }
    }
  }

  void _validateValuationAmount() {
    if (valuationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'A balance snapshot must contain a known historical valuation.',
      );
    }

    if (assetBalances.isEmpty && valuationAmount.amount != Decimal.zero) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'A snapshot without asset balances must have zero valuation.',
      );
    }
  }

  void _validateDirectValuation() {
    if (assetBalances.length != 1) {
      return;
    }

    final assetBalance = assetBalances.single;

    if (assetBalance.assetId != valuationAmount.assetId) {
      return;
    }

    if (assetBalance.amount != valuationAmount.amount ||
        assetBalance.direction != valuationAmount.direction) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'When the only asset balance already uses the valuation asset, '
            'the valuation must equal that balance.',
      );
    }
  }

  static List<AssetAmount> _canonicalizeAssetBalances(
    List<AssetAmount> balances,
  ) {
    final canonical = List<AssetAmount>.of(
      balances,
    )..sort((left, right) => left.assetId.value.compareTo(right.assetId.value));

    return List.unmodifiable(canonical);
  }
}
