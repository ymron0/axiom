/// Application-wide spacing scale.
///
/// The scale is based on a 4dp grid and should be preferred over arbitrary
/// spacing values in shared and feature presentation code.
///
/// ## Invariants
///
/// All spacing values are non-negative.
///
/// Values increase monotonically from [xxSmall] to [xxLarge].
///
/// ## Semantics
///
/// Tokens express visual distance only. They do not encode feature-specific
/// layout decisions.
///
/// ## Contract
///
/// Use the smallest token that communicates the intended hierarchy. Arbitrary
/// values remain acceptable only when required by an external component or a
/// specific visual constraint.
abstract final class AppSpacing {
  /// No spacing.
  static const double none = 0;

  /// 4dp spacing.
  static const double xxSmall = 4;

  /// 8dp spacing.
  static const double xSmall = 8;

  /// 12dp spacing.
  static const double small = 12;

  /// 16dp spacing.
  static const double medium = 16;

  /// 24dp spacing.
  static const double large = 24;

  /// 32dp spacing.
  static const double xLarge = 32;

  /// 48dp spacing.
  static const double xxLarge = 48;
}
