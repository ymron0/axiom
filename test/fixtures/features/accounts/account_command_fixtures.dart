import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/accounts/application/commands/create_account_command.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';

/// Creates a reusable account creation command for tests.
CreateAccountCommand createAccountCommandFixture({
  String name = 'Test Account',
  String custodianId = 'custodian-bank',
  String denominationAssetId = 'asset-chf',
  AccountKind kind = AccountKind.checking,
  String? reference,
  EntityIcon icon = EntityIcon.accountBalance,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
}) {
  return CreateAccountCommand(
    name: name,
    custodianId: CustodianId.fromString(custodianId),
    denominationAssetId: AssetId.fromString(denominationAssetId),
    kind: kind,
    reference: reference,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
  );
}
