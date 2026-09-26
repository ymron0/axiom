import 'package:flutter/material.dart';

/// Concrete presentation colors resolved for an entity color identity.
///
/// Domain entities persist a semantic `EntityColor`; this object contains the
/// actual Flutter colors used to render that identity in the active theme.
///
/// ## Invariants
///
/// Every palette contains colors for both direct accent rendering and
/// container rendering.
///
/// Foreground colors are selected to contrast with their corresponding
/// backgrounds.
///
/// ## Semantics
///
/// [accent] is intended for prominent entity-colored elements such as icons,
/// progress indicators, or narrow identity stripes.
///
/// [container] is intended for larger or softer colored surfaces.
///
/// ## Contract
///
/// Domain entities must never persist values from this class. Persisted visual
/// identity remains represented by the domain `EntityColor` enum.
@immutable
final class EntityColorPalette {
  /// Primary entity accent.
  final Color accent;

  /// Foreground suitable for [accent].
  final Color onAccent;

  /// Softer entity-colored surface.
  final Color container;

  /// Foreground suitable for [container].
  final Color onContainer;

  /// Creates a resolved entity color palette.
  const EntityColorPalette({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.onContainer,
  });
}
