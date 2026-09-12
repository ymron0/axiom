// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'entity_logo_source.mapper.dart';

/// Identifies whether an entity logo references a bundled application asset or
/// a remotely hosted image.
@MappableEnum()
enum EntityLogoSource {
  /// An asset bundled with the application.
  asset,

  /// An image hosted remotely.
  remote,
}
