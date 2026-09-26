import 'package:flutter/animation.dart';

/// Application-wide motion tokens.
///
/// Accessibility remains authoritative over these values. Presentation code
/// must disable or reduce animation when the platform requests reduced motion.
///
/// ## Invariants
///
/// Durations are non-negative.
///
/// ## Semantics
///
/// [fast] is intended for small state changes.
///
/// [standard] is the default duration for ordinary component transitions.
///
/// [slow] is reserved for larger visual transitions.
///
/// ## Contract
///
/// These tokens describe motion when animation is enabled. They must never
/// override platform accessibility preferences.
abstract final class AppMotion {
  /// Fast component transition.
  static const Duration fast = Duration(milliseconds: 120);

  /// Standard application transition.
  static const Duration standard = Duration(milliseconds: 180);

  /// Deliberate larger transition.
  static const Duration slow = Duration(milliseconds: 300);

  /// Standard transition curve.
  static const Curve standardCurve = Curves.easeOutCubic;
}
