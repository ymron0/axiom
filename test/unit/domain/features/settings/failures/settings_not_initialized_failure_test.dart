import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsNotInitializedFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = SettingsNotInitializedFailure();

      // Then
      expect(failure.type, SettingsNotInitializedFailure.typeId);
    });
  });
}
