import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/features/custodians/application/commands/create_custodian_command.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';

/// Creates a reusable custodian creation command for tests.
CreateCustodianCommand createCustodianCommandFixture({
  String name = 'Test Custodian',
  CustodianKind kind = CustodianKind.bank,
  EntityIcon icon = EntityIcon.accountBalance,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
}) {
  return CreateCustodianCommand(
    name: name,
    kind: kind,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
  );
}
