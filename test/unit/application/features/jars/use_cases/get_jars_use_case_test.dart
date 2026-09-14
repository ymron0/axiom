@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('GetJarsUseCase', () {
    late MockJarRepository repository;
    late GetJarsUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = GetJarsUseCase(repository);
    });

    test('returns all repository jars', () async {
      // Given
      final jars = [jarFixture(id: 'all')];
      when(() => repository.getAll()).thenAnswer((_) async => Success<List<Jar>>(jars));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(jars));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = JarNotFoundFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
