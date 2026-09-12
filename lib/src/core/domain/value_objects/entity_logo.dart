import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'entity_logo.mapper.dart';

/// A logo associated with a domain entity.
///
/// A logo may either reference an asset bundled with the application or a
/// remotely hosted image.
///
/// The entity's [EntityIcon] remains the required fallback when the logo is
/// unavailable, fails to load, or is not configured.
///
/// Logo references describe the source of the image only. Loading, caching,
/// decoding, network access, and rendering are presentation or infrastructure
/// concerns.
@MappableClass()
final class EntityLogo with EntityLogoMappable {
  /// The kind of source represented by this logo.
  final EntityLogoSource source;

  /// The source-specific logo location.
  ///
  /// For [EntityLogoSource.asset], this is an application asset path.
  ///
  /// For [EntityLogoSource.remote], this is a remote URL.
  final String value;

  /// Creates an entity logo.
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  EntityLogo({required this.source, required String value})
    : value = value.trim() {
    if (this.value.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Entity logo value cannot be blank.',
      );
    }
  }

  /// Creates a logo backed by an application asset.
  factory EntityLogo.asset(String path) {
    return EntityLogo(source: EntityLogoSource.asset, value: path);
  }

  /// Creates a logo backed by a remotely hosted image.
  factory EntityLogo.remote(String url) {
    return EntityLogo(source: EntityLogoSource.remote, value: url);
  }

  /// Whether this logo references an application asset.
  bool get isAsset => source == EntityLogoSource.asset;

  /// Whether this logo references a remotely hosted image.
  bool get isRemote => source == EntityLogoSource.remote;
}
