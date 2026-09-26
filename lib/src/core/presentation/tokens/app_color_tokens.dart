import 'package:flutter/material.dart';

/// Primitive application-wide color tokens.
///
/// Material semantic colors such as primary, surface, error, and container
/// colors remain owned by [ColorScheme]. This class contains only color
/// primitives required to construct that scheme.
///
/// Feature-specific semantic colors do not belong here.
///
/// ## Invariants
///
/// Tokens are immutable compile-time presentation configuration.
///
/// ## Semantics
///
/// [seed] is the source color used to generate the Material 3 color scheme.
///
/// ## Contract
///
/// Widgets should normally consume colors through `Theme.of(context)` rather
/// than accessing these primitives directly.
abstract final class AppColorTokens {
  /// Seed color used to generate the Material 3 color scheme.
  static const Color seed = Color(0xFF456B65);
}
