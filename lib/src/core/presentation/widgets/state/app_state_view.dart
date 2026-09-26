import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Shared visual structure for full-content presentation states.
///
/// This component owns the common layout used by empty and error states.
/// Loading state remains separate because its accessibility and visual
/// semantics differ.
///
/// ## Invariants
///
/// [title] is required.
///
/// [iconSize] must be greater than zero.
///
/// ## Semantics
///
/// The title is exposed as an accessibility heading.
///
/// When [liveRegion] is true, accessibility services may announce the state
/// when it appears.
///
/// ## Contract
///
/// This widget is presentation-only. It does not interpret domain failures,
/// perform retries, or own asynchronous state.
final class AppStateView extends StatelessWidget {
  /// Icon representing this state.
  final IconData icon;

  /// State title.
  final String title;

  /// Optional explanatory text.
  final String? message;

  /// Optional action rendered below the state description.
  final Widget? action;

  /// Icon color.
  final Color? iconColor;

  /// Icon size.
  final double iconSize;

  /// Whether this state should be exposed as a live accessibility region.
  final bool liveRegion;

  /// Creates a shared presentation state view.
  const AppStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
    this.iconSize = AppSize.entityVisualLarge,
    this.liveRegion = false,
    super.key,
  }) : assert(iconSize > 0, 'State icon size must be greater than zero.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: liveRegion,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.stateContentMaxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.medium),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.large),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
