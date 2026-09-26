/// Application-wide corner-radius scale.
///
/// ## Invariants
///
/// All radius values are non-negative.
///
/// ## Semantics
///
/// Increasing values communicate progressively softer or more prominent
/// surfaces.
///
/// [full] is intended for shapes that must remain visually pill-like.
///
/// ## Contract
///
/// Feature widgets should select from this scale instead of introducing
/// arbitrary corner radii unless their visual semantics require otherwise.
abstract final class AppRadius {
  /// Square corners.
  static const double none = 0;

  /// Subtle rounding for compact surfaces.
  static const double small = 8;

  /// Standard rounding for controls and indicators.
  static const double medium = 12;

  /// Standard rounding for cards and prominent controls.
  static const double large = 16;

  /// Large rounding for modal surfaces.
  static const double xLarge = 28;

  /// Effectively fully rounded for ordinary component dimensions.
  static const double full = 999;
}
