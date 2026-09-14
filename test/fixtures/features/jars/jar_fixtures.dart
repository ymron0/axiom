import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/jars/application/commands/create_jar_command.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';

/// Creates a valid jar snapshot for tests.
Jar jarFixture({
  required String id,
  String name = 'Test Jar',
  JarKind kind = JarKind.savingsGoal,
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Jar(
    id: JarId.fromString(id),
    name: name,
    kind: kind,
    icon: EntityIcon.savings,
    color: EntityColor.blue,
    sortOrder: 0,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? archivedAt ?? createdAt,
    entityVersion: 1,
  );
}

/// Creates a reusable jar creation command for tests.
CreateJarCommand createJarCommandFixture({
  String name = 'Created Jar',
  JarKind kind = JarKind.savingsGoal,
}) {
  return CreateJarCommand(
    name: name,
    kind: kind,
    icon: EntityIcon.savings,
    color: EntityColor.blue,
    sortOrder: 0,
  );
}
