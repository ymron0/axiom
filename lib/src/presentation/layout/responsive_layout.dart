import 'package:axiom/src/presentation/layout/window_size_class.dart';
import 'package:flutter/widgets.dart';

/// Selects layout variants based on the available width.
///
/// The compact layout is mandatory because phone-sized presentation is the
/// primary experience.
///
/// ## Semantics
///
/// [compact] is used for compact widths.
///
/// [medium] is used for medium widths when supplied. Otherwise [compact] is
/// used as the fallback.
///
/// [expanded] is used for expanded widths when supplied. Otherwise [medium]
/// is used when available, falling back to [compact].
///
/// ## Contract
///
/// Layout selection is based on the constraints supplied by the parent rather
/// than the physical device size. This allows the widget to work correctly
/// inside nested responsive layouts as well as full-screen layouts.
final class ResponsiveLayout extends StatelessWidget {
  /// Layout used for compact widths.
  final Widget compact;

  /// Optional layout used for medium widths.
  final Widget? medium;

  /// Optional layout used for expanded widths.
  final Widget? expanded;

  /// Creates a responsive layout.
  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  /// Returns the presentation size class for [width].
  static WindowSizeClass sizeClassFor(double width) {
    return WindowSizeClass.fromWidth(width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = sizeClassFor(constraints.maxWidth);

        return switch (sizeClass) {
          WindowSizeClass.compact => compact,
          WindowSizeClass.medium => medium ?? compact,
          WindowSizeClass.expanded => expanded ?? medium ?? compact,
        };
      },
    );
  }
}
