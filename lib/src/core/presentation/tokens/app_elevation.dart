/// Application-wide Material elevation scale.
///
/// ## Invariants
///
/// Elevation values are non-negative and increase by level.
///
/// ## Semantics
///
/// Elevation communicates visual layering. Most application surfaces should
/// remain at [level0] unless layering needs to be communicated explicitly.
///
/// ## Contract
///
/// Prefer Material component defaults or these levels instead of arbitrary
/// elevation values.
abstract final class AppElevation {
  /// No elevation.
  static const double level0 = 0;

  /// Low elevation.
  static const double level1 = 1;

  /// Low-to-medium elevation.
  static const double level2 = 3;

  /// Medium elevation.
  static const double level3 = 6;

  /// High elevation.
  static const double level4 = 8;

  /// Highest standard application elevation.
  static const double level5 = 12;
}
