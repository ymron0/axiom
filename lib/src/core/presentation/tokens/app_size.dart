/// Application-wide component sizing tokens.
///
/// ## Invariants
///
/// Interactive control dimensions preserve the minimum target size expected
/// by the application's presentation system.
///
/// ## Semantics
///
/// These values describe reusable component dimensions, not responsive
/// breakpoints. Responsive width ownership remains with `WindowSizeClass`.
///
/// ## Contract
///
/// Feature widgets should avoid redefining globally shared component sizes.
abstract final class AppSize {
  /// Minimum dimension of a primary interactive target.
  static const double interactive = 48;

  /// Small icon size.
  static const double iconSmall = 18;

  /// Standard icon size.
  static const double iconMedium = 24;

  /// Large icon size.
  static const double iconLarge = 32;

  /// Default entity visual size.
  static const double entityVisual = 40;

  /// Large entity visual size.
  static const double entityVisualLarge = 48;

  /// Height of the persistent primary navigation bar.
  static const double navigationBarHeight = 72;

  /// Maximum width for state messages.
  static const double stateContentMaxWidth = 360;

  /// Preferred maximum width for medium application content.
  static const double contentMaxWidthMedium = 720;

  /// Preferred maximum width for expanded application content.
  static const double contentMaxWidthExpanded = 1120;
}
