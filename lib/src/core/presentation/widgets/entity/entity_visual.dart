import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Displays the visual identity of an entity.
///
/// A configured logo is attempted first. The domain [EntityIcon] is used as
/// the fallback when no logo exists, while loading a remote logo, or when logo
/// rendering fails.
///
/// ## Invariants
///
/// [size] must be greater than zero.
///
/// The icon fallback is always available.
///
/// ## Semantics
///
/// Entity colors adapt to the active theme.
///
/// Logos are optional decoration. A failed logo does not turn the entity into
/// an error state because the domain explicitly defines [EntityIcon] as its
/// visual fallback.
///
/// ## Contract
///
/// This component performs presentation-only image rendering. It must not
/// persist image state or mutate the entity.
///
/// Logo failures are intentionally recovered locally by displaying the icon;
/// they are not converted into application failures.
final class EntityVisual extends StatelessWidget {
  /// Domain icon identity.
  final EntityIcon icon;

  /// Domain color identity.
  final EntityColor color;

  /// Optional entity logo.
  final EntityLogo? logo;

  /// Width and height of the visual.
  final double size;

  /// Optional accessibility description.
  ///
  /// Leave null when surrounding content already identifies the entity and
  /// this visual is purely decorative.
  final String? semanticLabel;

  /// Creates an entity visual.
  const EntityVisual({
    required this.icon,
    required this.color,
    this.logo,
    this.size = AppSize.entityVisual,
    this.semanticLabel,
    super.key,
  }) : assert(size > 0, 'Entity visual size must be greater than zero.');

  @override
  Widget build(BuildContext context) {
    final palette = EntityColorResolver.resolve(
      color,
      Theme.of(context).brightness,
    );

    final fallback = Icon(
      EntityIconResolver.resolve(icon),
      size: size * 0.55,
      color: palette.accent,
    );

    final visual = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: logo == null
              ? Center(child: fallback)
              : _buildLogo(logo!, fallback),
        ),
      ),
    );

    if (semanticLabel == null) {
      return ExcludeSemantics(child: visual);
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: visual),
    );
  }

  Widget _buildLogo(EntityLogo logo, Widget fallback) {
    final image = switch (logo.source) {
      EntityLogoSource.asset => Image.asset(
        logo.value,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(child: fallback),
      ),
      EntityLogoSource.remote => Image.network(
        logo.value,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Center(child: fallback);
        },
        errorBuilder: (_, _, _) => Center(child: fallback),
      ),
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxSmall),
      child: image,
    );
  }
}
