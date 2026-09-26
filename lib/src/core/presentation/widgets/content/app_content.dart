import 'package:axiom/src/core/presentation/layout/window_size_class.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Provides responsive horizontal framing for ordinary application content.
///
/// ## Semantics
///
/// Compact layouts use the full available width with standard horizontal
/// padding.
///
/// Medium and expanded layouts progressively increase padding and constrain
/// excessively wide content.
///
/// ## Contract
///
/// This widget controls layout only. It does not introduce scrolling,
/// application bars, loading state, or feature-specific behavior.
final class AppContent extends StatelessWidget {
  /// Content rendered inside the responsive frame.
  final Widget child;

  /// Optional custom padding.
  ///
  /// When omitted, responsive application padding is used.
  final EdgeInsetsGeometry? padding;

  /// Creates responsive application content.
  const AppContent({required this.child, this.padding, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);

        final horizontalPadding = switch (sizeClass) {
          WindowSizeClass.compact => AppSpacing.medium,
          WindowSizeClass.medium => AppSpacing.large,
          WindowSizeClass.expanded => AppSpacing.xLarge,
        };

        final maxWidth = switch (sizeClass) {
          WindowSizeClass.compact => double.infinity,
          WindowSizeClass.medium => AppSize.contentMaxWidthMedium,
          WindowSizeClass.expanded => AppSize.contentMaxWidthExpanded,
        };

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding:
                  padding ??
                  EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppSpacing.medium,
                  ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
