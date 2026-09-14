@Tags(['application'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/features/jars/application/commands/create_jar_command.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:test/test.dart';

void main() {
  group('CreateJarCommand', () {
    test('retains the supplied jar creation input', () {
      // Given / When
      const command = CreateJarCommand(
        name: 'Emergency fund',
        description: 'For unexpected costs',
        kind: JarKind.reserve,
        icon: EntityIcon.savings,
        color: EntityColor.blue,
        sortOrder: 3,
      );

      // Then
      expect(command.name, 'Emergency fund');
      expect(command.description, 'For unexpected costs');
      expect(command.kind, JarKind.reserve);
      expect(command.targets, isEmpty);
      expect(command.icon, EntityIcon.savings);
      expect(command.color, EntityColor.blue);
      expect(command.sortOrder, 3);
    });
  });
}
