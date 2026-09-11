import 'package:axiom/src/features/settings/data/repositories/in_memory_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('settingsRepositoryProvider', () {
    test('provides the in-memory settings repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(settingsRepositoryProvider);

      // Then
      expect(repository, isA<InMemorySettingsRepositoryImpl>());
    });
  });
}
