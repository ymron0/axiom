@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/archive_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('ArchiveJarUseCase', () {
    late MockJarRepository repository;
    late ArchiveJarUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 2);

    setUp(() {
      repository = MockJarRepository();
      useCase = ArchiveJarUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('archives the jar with the injected clock time', () async {
      // Given
      final jar = jarFixture(id: 'archive', archivedAt: timestamp);
      when(
        () => repository.archive(jar.id, timestamp),
      ).thenAnswer((_) async => Success<Jar>(jar));

      // When
      final result = await useCase(jar.id);

      // Then
      expect(result.valueOrNull, same(jar));
      verify(() => repository.archive(jar.id, timestamp)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = jarFixture(id: 'missing').id;
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.archive(id, timestamp)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
