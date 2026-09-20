import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = SettingsRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, SettingsRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
