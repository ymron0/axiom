import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/search_jars_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('SearchJarsUseCase', () {
    late MockJarRepository repository;
    late SearchJarsUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      useCase = SearchJarsUseCase(repository);
    });

    test('returns repository jars matching the query', () async {
      // Given
      final jars = [jarFixture(id: 'search', name: 'Holiday fund')];
      when(
        () => repository.search('holiday'),
      ).thenAnswer((_) async => Success<List<Jar>>(jars));

      // When
      final result = await useCase('holiday');

      // Then
      expect(result.valueOrNull, same(jars));
      verify(() => repository.search('holiday')).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = JarNotFoundFailure(message: 'search failed');
      when(() => repository.search('holiday')).thenAnswer((_) async => failure);

      // When
      final result = await useCase('holiday');

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
