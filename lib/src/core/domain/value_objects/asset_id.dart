import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_id.mapper.dart';

/// A type-safe identifier for an asset.
///
/// Create one from a persisted value:
/// ```dart
/// final assetId = AssetId.fromString('asset-123');
/// ```
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
