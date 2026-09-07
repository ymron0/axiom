import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_id.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'asset_amount.mapper.dart';

/// An asset quantity and its direction.
///
/// An [amount] of `-1` represents an unknown quantity. Otherwise, [amount]
/// must be zero or positive.
///
/// ```dart
/// final amount = AssetAmount.incoming(
///   assetId: AssetId.fromString('asset-123'),
///   amount: Decimal.parse('12.5'),
/// );
/// ```
@MappableClass()
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

  /// Whether the quantity is unknown.
  bool get isUnknown => amount == Decimal.fromInt(-1);

  /// Whether this quantity is incoming.
  bool get isIncoming => direction == AssetAmountDirection.incoming;

  /// Whether this quantity is outgoing.
  bool get isOutgoing => direction == AssetAmountDirection.outgoing;

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
