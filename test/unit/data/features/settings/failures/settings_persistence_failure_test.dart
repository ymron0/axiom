@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/settings/data/failures/settings_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsPersistenceFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = SettingsPersistenceFailure();

      // Then
      expect(failure.type, SettingsPersistenceFailure.typeId);
    });
  });
}
