// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'entity_color.mapper.dart';

/// A stable visual color identity assigned to an entity.
///
/// This value represents a semantic color choice rather than a concrete
/// presentation color. It deliberately does not depend on Flutter's [Color]
/// type or contain ARGB values.
///
/// The presentation layer is responsible for mapping each value to the
/// appropriate colors for the active theme.
///
/// Persisting the semantic value rather than a concrete color allows the same
/// entity identity to adapt to light, dark, high-contrast, or future themes
/// without changing domain data.
@MappableEnum()
enum EntityColor {
  red,
  orange,
  amber,
  yellow,
  lime,
  green,
  teal,
  cyan,
  blue,
  indigo,
  violet,
  purple,
  pink,
  brown,
  grey,
}
