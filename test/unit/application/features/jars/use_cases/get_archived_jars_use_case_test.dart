@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_archived_jars_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('GetArchivedJarsUseCase', () {
    late MockJarRepository repository;
    late GetArchivedJarsUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = GetArchivedJarsUseCase(repository);
    });

    test('returns archived repository jars', () async {
      // Given
      final jars = [
        jarFixture(id: 'archived', archivedAt: DateTime.utc(2026, 1, 2)),
      ];
      when(() => repository.getArchived()).thenAnswer((_) async => Success<List<Jar>>(jars));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(jars));
      verify(() => repository.getArchived()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = JarNotFoundFailure(message: 'read failed');
      when(() => repository.getArchived()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
