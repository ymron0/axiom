import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'asset_amount.mapper.dart';

/// A quantity of one specific asset and its flow direction.
///
/// [assetId] is deliberately typed as [AssetId]. This is a domain invariant,
/// not an implementation detail: identifiers from unrelated domains cannot be
/// supplied through the static API.
///
/// ## Invariants
///
/// - [assetId] is a valid, immutable [AssetId].
/// - [amount] is zero, positive, or the reserved `-1` unknown sentinel.
/// - Zero is a valid known amount.
/// - [amount] stores magnitude; [direction] stores incoming or outgoing flow.
/// - The value is immutable after construction.
///
/// ## Semantics
///
/// [amount] is the non-negative magnitude of the quantity, while [direction]
/// describes whether that quantity enters or leaves the asset balance. An
/// [amount] of `-1` means that the quantity is unknown and is distinct from
/// zero.
///
/// ## Contract
///
/// Constructors reject negative values other than the reserved `-1` sentinel
/// with [ArgumentError]. The value retains its [AssetId], [amount], and
/// [direction] for equality and mapping.
///
/// ```dart
/// final amount = AssetAmount.incoming(
///   assetId: AssetId.fromString('asset-123'),
///   amount: Decimal.parse('12.5'),
/// );
/// ```
@MappableClass(includeCustomMappers: [DecimalMapper()])
final class AssetAmount with AssetAmountMappable {
  /// The asset whose quantity this value describes.
  final AssetId assetId;

  /// Whether the quantity is incoming or outgoing.
  final AssetAmountDirection direction;

  /// The quantity, or `-1` when the quantity is unknown.
  final Decimal amount;

  /// Creates an asset quantity with the specified [direction].
  ///
  /// Throws an [ArgumentError] when [amount] is negative and not exactly `-1`.
  AssetAmount({
    required this.assetId,
    required Decimal amount,
    required this.direction,
  }) : amount = _validateAmount(amount);

  /// Creates an incoming asset quantity.
  ///
  /// Throws an [ArgumentError] when [amount] is negative and not exactly `-1`.
  factory AssetAmount.incoming({
    required AssetId assetId,
    required Decimal amount,
  }) {
    return AssetAmount(
      assetId: assetId,
      amount: amount,
      direction: AssetAmountDirection.incoming,
    );
  }

  /// Creates an outgoing asset quantity.
  ///
  /// Throws an [ArgumentError] when [amount] is negative and not exactly `-1`.
  factory AssetAmount.outgoing({
    required AssetId assetId,
    required Decimal amount,
  }) {
    return AssetAmount(
      assetId: assetId,
      amount: amount,
      direction: AssetAmountDirection.outgoing,
    );
  }

  /// Whether the quantity is known.
  bool get isKnownAmount => amount != Decimal.fromInt(-1);

  /// Whether the quantity is unknown.
  bool get isUnknownAmount => amount == Decimal.fromInt(-1);

  /// Whether this quantity is incoming.
  bool get isIncoming => direction == AssetAmountDirection.incoming;

  /// Whether this quantity is outgoing.
  bool get isOutgoing => direction == AssetAmountDirection.outgoing;

  /// Adds [other] as a signed balance change for the same asset.
  ///
  /// Incoming amounts increase the result and outgoing amounts decrease it.
  /// Throws an [ArgumentError] when [other] belongs to a different asset or
  /// when either amount is unknown.
  AssetAmount add(AssetAmount other) {
    _ensureComparable(other);

    return _fromSignedAmount(_signedAmount + other._signedAmount);
  }

  /// Subtracts [other] as a signed balance change for the same asset.
  ///
  /// Throws an [ArgumentError] when [other] belongs to a different asset or
  /// when either amount is unknown.
  AssetAmount subtract(AssetAmount other) {
    _ensureComparable(other);

    return _fromSignedAmount(_signedAmount - other._signedAmount);
  }

  /// Whether this amount is greater than [other] as a signed balance change.
  ///
  /// Throws an [ArgumentError] when [other] belongs to a different asset or
  /// when either amount is unknown.
  bool isGreaterThan(AssetAmount other) {
    _ensureComparable(other);
    return _signedAmount > other._signedAmount;
  }

  /// Whether this amount is less than [other] as a signed balance change.
  ///
  /// Throws an [ArgumentError] when [other] belongs to a different asset or
  /// when either amount is unknown.
  bool isLessThan(AssetAmount other) {
    _ensureComparable(other);
    return _signedAmount < other._signedAmount;
  }

  /// Whether this amount equals [other] as a signed balance change.
  ///
  /// Throws an [ArgumentError] when [other] belongs to a different asset or
  /// when either amount is unknown.
  bool isEqualTo(AssetAmount other) {
    _ensureComparable(other);
    return _signedAmount == other._signedAmount;
  }

  Decimal get _signedAmount {
    return isIncoming ? amount : -amount;
  }

  AssetAmount _fromSignedAmount(Decimal signedAmount) {
    final resultDirection = signedAmount < Decimal.zero
        ? AssetAmountDirection.outgoing
        : signedAmount > Decimal.zero
        ? AssetAmountDirection.incoming
        : direction;

    return AssetAmount(
      assetId: assetId,
      amount: signedAmount.abs(),
      direction: resultDirection,
    );
  }

  void _ensureSameAsset(AssetAmount other) {
    if (assetId != other.assetId) {
      throw ArgumentError.value(
        other.assetId,
        'other',
        'Asset amounts must describe the same asset.',
      );
    }
  }

  void _ensureComparable(AssetAmount other) {
    _ensureSameAsset(other);
    if (isUnknownAmount || other.isUnknownAmount) {
      throw ArgumentError.value(
        other,
        'other',
        'Unknown asset amounts cannot be compared.',
      );
    }
  }

  /// Rejects negative quantities other than the unknown sentinel value.
  static Decimal _validateAmount(Decimal amount) {
    final unknownAmount = Decimal.fromInt(-1);
    if (amount < Decimal.zero && amount != unknownAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be -1 (unknown), zero, or positive.',
      );
    }

    return amount;
  }
}
