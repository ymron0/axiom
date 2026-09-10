import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_id.mapper.dart';

/// A type-safe identifier for an asset.
///
/// [AssetId] remains owned by the Assets feature even though Core primitives
/// may reference it when they specifically identify an asset. This deliberate
/// exception lets APIs such as [AssetAmount] reject unrelated typed IDs at
/// compile time instead of accepting a generic [UniqueId]. Core must not use
/// this exception to depend on other Assets domain types.
///
/// Create one from a persisted value:
/// ```dart
/// final assetId = AssetId.fromString('asset-123');
/// ```
///
/// ## Invariants
///
/// The serialized value is non-empty, not solely whitespace, immutable, and
/// stable for the lifetime of this identifier. Generated values obey the same
/// validation contract. Valid supplied values are preserved exactly without
/// silent trimming or normalization.
///
/// ## Semantics
///
/// The Dart type represents asset identity and must not be substituted for an
/// unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new asset IDs.
@MappableClass()
final class AssetId extends UniqueId with AssetIdMappable {
  /// Creates an asset identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  AssetId.fromString(super.value);

  /// Creates an asset identifier with a newly generated Nano ID value.
  AssetId.generate() : super.generate();
}
