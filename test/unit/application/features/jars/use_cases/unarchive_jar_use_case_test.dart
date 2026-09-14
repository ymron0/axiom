@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/unarchive_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('UnarchiveJarUseCase', () {
    late MockJarRepository repository;
    late UnarchiveJarUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 3);

    setUp(() {
      repository = MockJarRepository();
      useCase = UnarchiveJarUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('unarchives the jar with the injected clock time', () async {
      // Given
      final jar = jarFixture(id: 'unarchive', modifiedAt: timestamp);
      when(
        () => repository.unarchive(jar.id, timestamp),
      ).thenAnswer((_) async => Success<Jar>(jar));

      // When
      final result = await useCase(jar.id);

      // Then
      expect(result.valueOrNull, same(jar));
      verify(() => repository.unarchive(jar.id, timestamp)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = jarFixture(id: 'missing').id;
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.unarchive(id, timestamp)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
