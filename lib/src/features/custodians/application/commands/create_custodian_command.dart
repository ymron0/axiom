import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';

/// Input required to create and persist a new custodian.
///
/// Generated identity, version, audit metadata, and deletion state are
/// intentionally excluded.
final class CreateCustodianCommand {
  /// Creates a custodian creation command.
  const CreateCustodianCommand({
    required this.name,
    required this.kind,
    this.logo,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  /// The custodian's human-readable name.
  final String name;

  /// The custodian's semantic kind.
  final CustodianKind kind;

  /// An optional logo associated with the custodian.
  final EntityLogo? logo;

  /// The custodian's fallback visual icon.
  final EntityIcon icon;

  /// The custodian's semantic visual color.
  final EntityColor color;

  /// The custodian's user-defined ordering position.
  final int sortOrder;
}
