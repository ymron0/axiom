import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('GetJarByIdUseCase', () {
    late MockJarRepository repository;
    late GetJarByIdUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = GetJarByIdUseCase(repository);
    });

    test('returns the repository jar for the requested identity', () async {
      // Given
      final jar = jarFixture(id: 'jar');
      when(() => repository.getById(jar.id)).thenAnswer((_) async => Success<Jar?>(jar));

      // When
      final result = await useCase(jar.id);

      // Then
      expect(result.valueOrNull, same(jar));
      verify(() => repository.getById(jar.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = jarFixture(id: 'missing').id;
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
