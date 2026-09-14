@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/update_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('UpdateJarUseCase', () {
    late MockJarRepository repository;
    late UpdateJarUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = UpdateJarUseCase(repository);
    });

    test('updates an active jar', () async {
      // Given
      final jar = jarFixture(id: 'update');
      when(() => repository.update(jar)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(jar);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(jar)).called(1);
    });

    test('rejects a deleted jar without updating it', () async {
      // Given
      final jar = jarFixture(
        id: 'deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, isA<JarAlreadyDeletedFailure>());
      verifyNever(() => repository.update(jar));
    });

    test('propagates repository failures', () async {
      // Given
      final jar = jarFixture(id: 'missing');
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.update(jar)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
