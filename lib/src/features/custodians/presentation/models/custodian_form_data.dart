import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/features/custodians/application/commands/create_custodian_command.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';

/// Editable custodian values owned by presentation.
final class CustodianFormData {
  /// Creates custodian form data.
  const CustodianFormData({
    required this.name,
    required this.kind,
    required this.logoSource,
    required this.logoValue,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  final String name;
  final CustodianKind kind;
  final EntityLogoSource logoSource;
  final String? logoValue;
  final EntityIcon icon;
  final EntityColor color;
  final int sortOrder;

  /// Creates form data from an existing custodian.
  factory CustodianFormData.fromCustodian(Custodian custodian) {
    return CustodianFormData(
      name: custodian.name,
      kind: custodian.kind,
      logoSource: custodian.logo?.source ?? EntityLogoSource.remote,
      logoValue: custodian.logo?.value,
      icon: custodian.icon,
      color: custodian.color,
      sortOrder: custodian.sortOrder,
    );
  }

  /// Converts values to an application creation command.
  CreateCustodianCommand toCreateCommand() {
    return CreateCustodianCommand(
      name: name.trim(),
      kind: kind,
      logo: _buildLogo(),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
    );
  }

  /// Applies editable values while preserving lifecycle metadata.
  Custodian applyTo(Custodian custodian, {required DateTime modifiedAt}) {
    return Custodian(
      id: custodian.id,
      name: name.trim(),
      kind: kind,
      logo: _buildLogo(),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      archivedAt: custodian.archivedAt,
      deletedAt: custodian.deletedAt,
      createdAt: custodian.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: custodian.entityVersion,
    );
  }

  EntityLogo? _buildLogo() {
    final normalized = logoValue?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return EntityLogo(source: logoSource, value: normalized);
  }
}
