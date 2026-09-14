import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/restore_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('RestoreJarUseCase', () {
    late MockJarRepository repository;
    late RestoreJarUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = RestoreJarUseCase(repository);
    });

    test('restores a deleted jar snapshot', () async {
      // Given
      final jar = jarFixture(
        id: 'restore',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(() => repository.restore(jar)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(jar);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(jar)).called(1);
    });

    test('rejects an active jar without restoring it', () async {
      // Given
      final jar = jarFixture(id: 'active');

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, isA<JarNotDeletedFailure>());
      verifyNever(() => repository.restore(jar));
    });

    test('propagates repository failures', () async {
      // Given
      final jar = jarFixture(
        id: 'existing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = JarAlreadyExistsFailure(message: 'existing');
      when(() => repository.restore(jar)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
