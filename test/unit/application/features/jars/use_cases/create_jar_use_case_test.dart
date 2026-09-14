@Tags(['application'])
library;

import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/create_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';
import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('CreateJarUseCase', () {
    late MockJarRepository repository;
    late MockSettingsRepository settingsRepository;
    late CreateJarUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 2);

    setUpAll(() {
      registerFallbackValue(jarFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockJarRepository();
      settingsRepository = MockSettingsRepository();
      useCase = CreateJarUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
        validateTargetCurrencies: ValidateJarTargetCurrenciesService(
          getSettings: GetSettingsUseCase(settingsRepository),
        ),
      );
    });

    test('creates an active jar with the injected clock', () async {
      // Given
      final command = createJarCommandFixture(name: '  Holiday fund  ');
      when(() => repository.create(any())).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final jar = result.valueOrNull!;
      expect(jar.name, 'Holiday fund');
      expect(jar.kind, command.kind);
      expect(jar.icon, command.icon);
      expect(jar.color, command.color);
      expect(jar.sortOrder, command.sortOrder);
      expect(jar.createdAt, timestamp);
      expect(jar.modifiedAt, timestamp);
      expect(jar.entityVersion, 1);
      expect(jar.isArchived, isFalse);
      expect(jar.isDeleted, isFalse);
      verify(() => repository.create(jar)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = createJarCommandFixture();
      const failure = JarAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
