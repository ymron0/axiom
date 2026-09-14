import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/archive_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/create_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/delete_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_active_jars_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_archived_jars_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_by_kind_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/restore_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/search_jars_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/unarchive_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/update_jar_use_case.dart';
import 'package:axiom/src/features/jars/data/repositories/in_memory_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/di/archive_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/create_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/delete_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_active_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_archived_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jars_by_kind_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:axiom/src/features/jars/di/restore_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/search_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/unarchive_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/update_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';

void main() {
  group('jar use-case providers', () {
    setUpAll(() {
      registerFallbackValue(jarFixture(id: 'fallback'));
    });

    test('resolves every use case from the default repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(jarRepositoryProvider);
      final useCases = [
        container.read(createJarUseCaseProvider),
        container.read(getJarsUseCaseProvider),
        container.read(getActiveJarsUseCaseProvider),
        container.read(getArchivedJarsUseCaseProvider),
        container.read(getJarByIdUseCaseProvider),
        container.read(getJarsByKindUseCaseProvider),
        container.read(searchJarsUseCaseProvider),
        container.read(updateJarUseCaseProvider),
        container.read(archiveJarUseCaseProvider),
        container.read(unarchiveJarUseCaseProvider),
        container.read(deleteJarUseCaseProvider),
        container.read(restoreJarUseCaseProvider),
      ];

      // Then
      expect(repository, isA<InMemoryJarRepositoryImpl>());
      expect(useCases, hasLength(12));
      expect(useCases[0], isA<CreateJarUseCase>());
      expect(useCases[1], isA<GetJarsUseCase>());
      expect(useCases[2], isA<GetActiveJarsUseCase>());
      expect(useCases[3], isA<GetArchivedJarsUseCase>());
      expect(useCases[4], isA<GetJarByIdUseCase>());
      expect(useCases[5], isA<GetJarsByKindUseCase>());
      expect(useCases[6], isA<SearchJarsUseCase>());
      expect(useCases[7], isA<UpdateJarUseCase>());
      expect(useCases[8], isA<ArchiveJarUseCase>());
      expect(useCases[9], isA<UnarchiveJarUseCase>());
      expect(useCases[10], isA<DeleteJarUseCase>());
      expect(useCases[11], isA<RestoreJarUseCase>());
    });

    test('injects the overridden repository into every use case', () async {
      // Given
      final repository = MockJarRepository();
      final jar = jarFixture(id: 'provider-jar');
      final deleted = jarFixture(
        id: 'provider-deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      final archived = jarFixture(
        id: jar.id.value,
        archivedAt: DateTime.utc(2026, 1, 2),
      );
      final clock = FixedClock(DateTime.utc(2026, 1, 3));
      when(() => repository.create(any())).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.getAll()).thenAnswer(
        (_) async => Success<List<Jar>>([jar]),
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success<List<Jar>>([jar]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success<List<Jar>>([archived]),
      );
      when(() => repository.getById(jar.id)).thenAnswer(
        (_) async => Success<Jar?>(jar),
      );
      when(() => repository.getByKind(jar.kind)).thenAnswer(
        (_) async => Success<List<Jar>>([jar]),
      );
      when(() => repository.search('jar')).thenAnswer(
        (_) async => Success<List<Jar>>([jar]),
      );
      when(() => repository.update(jar)).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.archive(jar.id, clock.nowUtc)).thenAnswer(
        (_) async => Success(archived),
      );
      when(() => repository.unarchive(jar.id, clock.nowUtc)).thenAnswer(
        (_) async => Success(jar),
      );
      when(() => repository.delete(jar.id)).thenAnswer(
        (_) async => Success(jar),
      );
      when(() => repository.restore(deleted)).thenAnswer(
        (_) async => const Success(null),
      );
      final container = ProviderContainer(
        overrides: [
          jarRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);

      // When
      final created = await container.read(createJarUseCaseProvider)(
        createJarCommandFixture(),
      );
      await container.read(getJarsUseCaseProvider)();
      await container.read(getActiveJarsUseCaseProvider)();
      await container.read(getArchivedJarsUseCaseProvider)();
      await container.read(getJarByIdUseCaseProvider)(jar.id);
      await container.read(getJarsByKindUseCaseProvider)(jar.kind);
      await container.read(searchJarsUseCaseProvider)('jar');
      await container.read(updateJarUseCaseProvider)(jar);
      await container.read(archiveJarUseCaseProvider)(jar.id);
      await container.read(unarchiveJarUseCaseProvider)(jar.id);
      await container.read(deleteJarUseCaseProvider)(jar.id);
      await container.read(restoreJarUseCaseProvider)(deleted);

      // Then
      expect(created.isSuccess, isTrue);
      verify(() => repository.create(any())).called(1);
      verify(() => repository.getAll()).called(1);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
      verify(() => repository.getById(jar.id)).called(1);
      verify(() => repository.getByKind(jar.kind)).called(1);
      verify(() => repository.search('jar')).called(1);
      verify(() => repository.update(jar)).called(1);
      verify(() => repository.archive(jar.id, clock.nowUtc)).called(1);
      verify(() => repository.unarchive(jar.id, clock.nowUtc)).called(1);
      verify(() => repository.delete(jar.id)).called(1);
      verify(() => repository.restore(deleted)).called(1);
    });
  });
}
