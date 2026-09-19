import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'balance_snapshot.mapper.dart';

/// Immutable daily closing-balance snapshot for an account, custodian, or jar.
///
/// A snapshot contains three related financial representations:
///
/// - [assetBalances] records the actual per-asset positions;
/// - [denominationAmount] records their aggregate value in the subject's own
///   denomination currency; and
/// - [valuationAmount] records their aggregate value in the user's configured
///   base valuation currency.
///
/// ## Account semantics
///
/// Accounts may hold several assets while having one denomination currency.
///
/// For an account:
///
/// - [assetBalances] contains all held assets;
/// - [denominationAmount] is the total position valued in the account's
///   denomination asset; and
/// - [valuationAmount] is the same total position valued in the user's base
///   valuation currency.
///
/// Therefore [denominationAmount] and [valuationAmount] may use different
/// assets.
///
/// ## Custodian semantics
///
/// Custodians are denominated directly in the user's base valuation currency.
///
/// Therefore:
///
/// ```text
/// denominationAmount == valuationAmount
/// ```
///
/// ## Jar semantics
///
/// Jars are also denominated directly in the user's base valuation currency.
///
/// Therefore:
///
/// ```text
/// denominationAmount == valuationAmount
/// ```
///
/// ## Historical semantics
///
/// Both aggregate values are stored historical values. Historical reports must
/// not silently recalculate them using newer exchange rates.
///
/// Transactions and allocations remain authoritative. Snapshots are derived
/// projections and may be rebuilt when historical financial state changes.
@MappableClass()
final class BalanceSnapshot with BalanceSnapshotMappable {
  /// Account, custodian, or jar represented by this snapshot.
  final BalanceSnapshotSubject subject;

  /// Calendar date whose closing financial position is represented.
  final CalendarDate snapshotDate;

  /// UTC instant at which this snapshot representation was calculated.
  final DateTime capturedAt;

  /// Closing positions grouped by asset.
  ///
  /// Each asset occurs at most once.
  final List<AssetAmount> assetBalances;

  /// Aggregate value in the subject's denomination asset.
  ///
  /// For accounts, this uses the account's denomination asset.
  ///
  /// For custodians and jars, this uses the user's base valuation currency and
  /// therefore equals [valuationAmount].
  final AssetAmount denominationAmount;

  /// Aggregate value in the user's configured base valuation currency.
  final AssetAmount valuationAmount;

  /// Creates an immutable daily balance snapshot.
  @MappableConstructor()
  BalanceSnapshot({
    required this.subject,
    required this.snapshotDate,
    required DateTime capturedAt,
    required List<AssetAmount> assetBalances,
    required this.denominationAmount,
    required this.valuationAmount,
  }) : capturedAt = capturedAt.toUtc(),
       assetBalances = _canonicalizeAssetBalances(assetBalances) {
    _validateAssetBalances();
    _validateAggregateAmounts();
    _validateEmptyPosition();
    _validateDirectValuation();
    _validateBaseDenominatedSubject();
  }

  void _validateAggregateAmounts() {
    if (denominationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        denominationAmount,
        'denominationAmount',
        'A balance snapshot must contain a known denomination amount.',
      );
    }

    if (valuationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'A balance snapshot must contain a known valuation amount.',
      );
    }
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

  void _validateBaseDenominatedSubject() {
    if (subject.isAccount) {
      return;
    }

    if (denominationAmount.assetId != valuationAmount.assetId ||
        denominationAmount.amount != valuationAmount.amount ||
        denominationAmount.direction != valuationAmount.direction) {
      throw ArgumentError.value(
        denominationAmount,
        'denominationAmount',
        'Custodian and jar denomination amounts must equal their valuation '
            'amounts.',
      );
    }
  }

  void _validateEmptyPosition() {
    if (assetBalances.isNotEmpty) {
      return;
    }

    if (denominationAmount.amount != Decimal.zero) {
      throw ArgumentError.value(
        denominationAmount,
        'denominationAmount',
        'A snapshot without asset balances must have zero denomination value.',
      );
    }

    if (valuationAmount.amount != Decimal.zero) {
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

    final balance = assetBalances.single;
    if (balance.assetId != valuationAmount.assetId) {
      return;
    }

    if (!balance.isEqualTo(valuationAmount)) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Valuation must equal the only balance when they use the same asset.',
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
