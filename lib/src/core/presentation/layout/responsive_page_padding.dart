import 'package:axiom/src/core/presentation/layout/window_size_class.dart';
import 'package:flutter/widgets.dart';

/// Applies width-aware padding around page content.
///
/// Compact screens use 16dp horizontal padding so content remains usable on
/// small phone layouts such as a 360dp-wide viewport.
///
/// Medium and expanded layouts progressively increase the available padding.
///
/// Custom padding may be supplied for any size class.
///
/// ## Contract
///
/// Padding is selected using the constraints supplied by the parent rather
/// than the physical device width.
final class ResponsivePagePadding extends StatelessWidget {
  /// Content receiving the responsive padding.
  final Widget child;

  /// Optional padding override for compact layouts.
  final EdgeInsets? compactPadding;

  /// Optional padding override for medium layouts.
  final EdgeInsets? mediumPadding;

  /// Optional padding override for expanded layouts.
  final EdgeInsets? expandedPadding;

  /// Creates responsive page padding.
  const ResponsivePagePadding({
    required this.child,
    this.compactPadding,
    this.mediumPadding,
    this.expandedPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);

        final padding = switch (sizeClass) {
          WindowSizeClass.compact =>
            compactPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          WindowSizeClass.medium =>
            mediumPadding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          WindowSizeClass.expanded =>
            expandedPadding ??
                const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        };

        return Padding(padding: padding, child: child);
      },
    );
  }
}
