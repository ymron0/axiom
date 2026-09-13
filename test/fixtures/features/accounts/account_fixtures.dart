import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';

/// Creates a valid account snapshot for tests.
Account accountFixture({
  required String id,
  String name = 'Test Account',
  String custodianId = 'custodian-bank',
  String denominationAssetId = 'asset-chf',
  AccountKind kind = AccountKind.checking,
  String? reference,
  EntityLogo? logo,
  EntityIcon icon = EntityIcon.accountBalance,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Account(
    id: AccountId.fromString(id),
    name: name,
    custodianId: CustodianId.fromString(custodianId),
    denominationAssetId: AssetId.fromString(denominationAssetId),
    kind: kind,
    reference: reference,
    logo: logo,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}
