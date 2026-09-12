import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsAlreadyInitializedFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = SettingsAlreadyInitializedFailure();

      // Then
      expect(failure.type, SettingsAlreadyInitializedFailure.typeId);
    });
  });
}
