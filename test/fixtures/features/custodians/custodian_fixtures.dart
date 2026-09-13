import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';

/// Creates a valid custodian snapshot for tests.
Custodian custodianFixture({
  required String id,
  String name = 'Test Custodian',
  CustodianKind kind = CustodianKind.bank,
  EntityLogo? logo,
  EntityIcon icon = EntityIcon.accountBalance,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Custodian(
    id: CustodianId.fromString(id),
    name: name,
    kind: kind,
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
