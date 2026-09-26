import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Shared heading for sections within a page.
///
/// ## Semantics
///
/// The title is exposed as an accessibility heading.
///
/// Optional supporting text provides additional context without changing
/// heading hierarchy.
///
/// ## Contract
///
/// This component does not provide surrounding page padding. Page-level layout
/// remains owned by [AppContent] or the feature screen.
final class AppSectionHeader extends StatelessWidget {
  /// Section title.
  final String title;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional action or status displayed opposite the title.
  final Widget? trailing;

  /// Creates a section header.
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxSmall),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.medium),
          trailing!,
        ],
      ],
    );
  }
}
