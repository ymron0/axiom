@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_by_kind_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('GetJarsByKindUseCase', () {
    late MockJarRepository repository;
    late GetJarsByKindUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = GetJarsByKindUseCase(repository);
    });

    test('returns repository jars with the requested kind', () async {
      // Given
      final jars = [jarFixture(id: 'reserve', kind: JarKind.reserve)];
      when(
        () => repository.getByKind(JarKind.reserve),
      ).thenAnswer((_) async => Success<List<Jar>>(jars));

      // When
      final result = await useCase(JarKind.reserve);

      // Then
      expect(result.valueOrNull, same(jars));
      verify(() => repository.getByKind(JarKind.reserve)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = JarNotFoundFailure(message: 'read failed');
      when(() => repository.getByKind(JarKind.reserve)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(JarKind.reserve);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
