import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Compact shared row for list-based presentation.
///
/// Unlike a card, this component does not create elevation or external spacing.
/// Consecutive items therefore form a dense continuous list.
///
/// ## Semantics
///
/// Interactive rows expose button semantics through [InkWell].
///
/// When [semanticLabel] is supplied, child semantics are excluded to avoid
/// duplicated accessibility announcements.
///
/// ## Contract
///
/// Feature-specific transaction, account, category, or merchant behavior does
/// not belong in this component. Those screens compose their own content into
/// [leading], [title], [subtitle], and [trailing].
final class AppListItem extends StatelessWidget {
  /// Optional leading visual.
  final Widget? leading;

  /// Primary row content.
  final Widget title;

  /// Optional secondary content.
  final Widget? subtitle;

  /// Optional trailing content.
  final Widget? trailing;

  /// Called when the item is activated.
  final VoidCallback? onTap;

  /// Called when the item is long-pressed.
  final VoidCallback? onLongPress;

  /// Whether interaction is enabled.
  final bool enabled;

  /// Whether this row represents a selected item.
  final bool selected;

  /// Optional explicit accessibility label.
  final String? semanticLabel;

  /// Creates a compact list item.
  const AppListItem({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.xSmall,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.small),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxSmall),
                    DefaultTextStyle(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.38,
                              ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.small),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        selected: selected,
        enabled: enabled,
        button: onTap != null || onLongPress != null,
        child: ExcludeSemantics(child: content),
      );
    }

    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: content,
      ),
    );
  }
}
