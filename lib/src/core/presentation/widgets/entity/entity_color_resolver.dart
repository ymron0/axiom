import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_palette.dart';
import 'package:flutter/material.dart';

/// Resolves domain [EntityColor] values into theme-aware presentation colors.
///
/// ## Invariants
///
/// Every [EntityColor] is mapped exhaustively.
///
/// Resolution is deterministic for a given color identity and brightness.
///
/// ## Semantics
///
/// Light themes use stronger accents with light containers.
///
/// Dark themes use lighter accents with dark containers.
///
/// The domain color remains stable while the rendered colors adapt to the
/// active presentation brightness.
///
/// ## Contract
///
/// This resolver cannot produce an expected recoverable failure because its
/// input is a closed domain enum.
///
/// Invalid persisted enum values must be rejected by the persistence/domain
/// boundary before reaching presentation.
abstract final class EntityColorResolver {
  /// Resolves [color] for the requested [brightness].
  static EntityColorPalette resolve(EntityColor color, Brightness brightness) {
    final swatch = _swatchFor(color);

    final accent = switch (brightness) {
      Brightness.light => swatch.shade700,
      Brightness.dark => swatch.shade300,
    };

    final container = switch (brightness) {
      Brightness.light => swatch.shade100,
      Brightness.dark => swatch.shade900,
    };

    return EntityColorPalette(
      accent: accent,
      onAccent: _foregroundFor(accent),
      container: container,
      onContainer: _foregroundFor(container),
    );
  }

  static MaterialColor _swatchFor(EntityColor color) {
    return switch (color) {
      EntityColor.red => Colors.red,
      EntityColor.orange => Colors.orange,
      EntityColor.amber => Colors.amber,
      EntityColor.yellow => Colors.yellow,
      EntityColor.lime => Colors.lime,
      EntityColor.green => Colors.green,
      EntityColor.teal => Colors.teal,
      EntityColor.cyan => Colors.cyan,
      EntityColor.blue => Colors.blue,
      EntityColor.indigo => Colors.indigo,
      EntityColor.violet => Colors.deepPurple,
      EntityColor.purple => Colors.purple,
      EntityColor.pink => Colors.pink,
      EntityColor.brown => Colors.brown,
      EntityColor.grey => Colors.grey,
    };
  }

  static Color _foregroundFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}
