import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';

/// Input required to create and persist a new jar.
///
/// Generated identity, audit metadata, archival state, and deletion state are
/// intentionally excluded.
final class CreateJarCommand {
  /// The jar's human-readable name.
  final String name;

  /// Optional user-provided details.
  final String? description;

  /// The jar's financial behavior.
  final JarKind kind;

  /// Historical, current, and future targets supplied at creation.
  final List<JarTarget> targets;

  /// The semantic visual icon.
  final EntityIcon icon;

  /// The semantic visual color.
  final EntityColor color;

  /// The user-defined ordering position.
  final int sortOrder;

  /// Creates a jar creation command.
  const CreateJarCommand({
    required this.name,
    this.description,
    required this.kind,
    this.targets = const [],
    required this.icon,
    required this.color,
    required this.sortOrder,
  });
}
