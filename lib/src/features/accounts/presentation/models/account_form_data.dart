import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/accounts/application/commands/create_account_command.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';

/// Editable presentation values for an account form.
///
/// ## Semantics
///
/// This type contains user-editable account data only. Identity, creation
/// metadata, deletion state, and archival state remain owned by the existing
/// domain entity.
///
/// ## Contract
///
/// Presentation validation must run before converting this value to a domain
/// command or updated entity snapshot.
final class AccountFormData {
  /// Creates account form data.
  const AccountFormData({
    required this.name,
    required this.custodianId,
    required this.denominationAssetId,
    required this.kind,
    required this.reference,
    required this.logoSource,
    required this.logoValue,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  final String name;
  final CustodianId custodianId;
  final AssetId denominationAssetId;
  final AccountKind kind;
  final String? reference;
  final EntityLogoSource logoSource;
  final String? logoValue;
  final EntityIcon icon;
  final EntityColor color;
  final int sortOrder;

  /// Creates presentation values from an existing account.
  factory AccountFormData.fromAccount(Account account) {
    return AccountFormData(
      name: account.name,
      custodianId: account.custodianId,
      denominationAssetId: account.denominationAssetId,
      kind: account.kind,
      reference: account.reference,
      logoSource: account.logo?.source ?? EntityLogoSource.remote,
      logoValue: account.logo?.value,
      icon: account.icon,
      color: account.color,
      sortOrder: account.sortOrder,
    );
  }

  /// Converts the form data to a creation command.
  CreateAccountCommand toCreateCommand() {
    return CreateAccountCommand(
      name: name.trim(),
      custodianId: custodianId,
      denominationAssetId: denominationAssetId,
      kind: kind,
      reference: _normalizedOptional(reference),
      logo: _buildLogo(),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
    );
  }

  /// Applies editable values to an existing account snapshot.
  ///
  /// Identity and lifecycle state are preserved.
  Account applyTo(Account account, {required DateTime modifiedAt}) {
    return Account(
      id: account.id,
      name: name.trim(),
      custodianId: custodianId,
      denominationAssetId: denominationAssetId,
      kind: kind,
      reference: _normalizedOptional(reference),
      logo: _buildLogo(),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      archivedAt: account.archivedAt,
      deletedAt: account.deletedAt,
      createdAt: account.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: account.entityVersion,
    );
  }

  EntityLogo? _buildLogo() {
    final normalized = _normalizedOptional(logoValue);

    if (normalized == null) {
      return null;
    }

    return EntityLogo(source: logoSource, value: normalized);
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
