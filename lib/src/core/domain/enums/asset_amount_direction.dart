// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'asset_amount_direction.mapper.dart';

/// Describes whether an asset amount enters or leaves its owning balance.
///
/// For example:
/// ```dart
/// const direction = AssetAmountDirection.incoming;
/// ```
@MappableEnum()
enum AssetAmountDirection {
  /// The amount increases the owning balance.
  incoming,

  /// The amount decreases the owning balance.
  outgoing,
}
