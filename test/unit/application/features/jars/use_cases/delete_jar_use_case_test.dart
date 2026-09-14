import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/delete_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('DeleteJarUseCase', () {
    late MockJarRepository repository;
    late DeleteJarUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = DeleteJarUseCase(repository);
    });

    test('deletes and returns the repository deleted snapshot', () async {
      // Given
      final jar = jarFixture(
        id: 'delete',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(() => repository.delete(jar.id)).thenAnswer((_) async => Success<Jar>(jar));

      // When
      final result = await useCase(jar.id);

      // Then
      expect(result.valueOrNull, same(jar));
      verify(() => repository.delete(jar.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = jarFixture(id: 'missing').id;
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.delete(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
