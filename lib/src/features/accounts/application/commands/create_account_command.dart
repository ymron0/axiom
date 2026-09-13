import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';

/// Input required to create and persist a new account.
///
/// Generated identity, version, audit metadata, and deletion state are
/// intentionally excluded.
final class CreateAccountCommand {
  /// Creates an account creation command.
  const CreateAccountCommand({
    required this.name,
    required this.custodianId,
    required this.denominationAssetId,
    required this.kind,
    this.reference,
    this.logo,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  /// The account's human-readable name.
  final String name;

  /// The custodian that holds the account.
  final CustodianId custodianId;

  /// The asset in which the account is denominated.
  final AssetId denominationAssetId;

  /// The account's semantic kind.
  final AccountKind kind;

  /// An optional user-facing account reference.
  final String? reference;

  /// An optional logo associated with the account.
  final EntityLogo? logo;

  /// The account's fallback visual icon.
  final EntityIcon icon;

  /// The account's semantic visual color.
  final EntityColor color;

  /// The account's user-defined ordering position.
  final int sortOrder;
}
