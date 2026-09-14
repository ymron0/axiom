@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/archive_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_active_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_archived_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/unarchive_category_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('category archival use cases', () {
    late MockCategoryRepository repository;
    late ArchiveCategoryUseCase archive;
    late UnarchiveCategoryUseCase unarchive;

    setUp(() {
      repository = MockCategoryRepository();
      final clock = FixedClock(timestamp);
      archive = ArchiveCategoryUseCase(repository: repository, clock: clock);
      unarchive = UnarchiveCategoryUseCase(repository: repository, clock: clock);
    });

    test('archive and unarchive forward the canonical timestamp', () async {
      // Given
      final category = categoryFixture(id: 'category');
      when(() => repository.archive(category.id, timestamp)).thenAnswer(
        (_) async => Success(category),
      );
      when(() => repository.unarchive(category.id, timestamp)).thenAnswer(
        (_) async => Success(category),
      );

      // When
      await archive(category.id);
      await unarchive(category.id);

      // Then
      verify(() => repository.archive(category.id, timestamp)).called(1);
      verify(() => repository.unarchive(category.id, timestamp)).called(1);
    });

    test('active and archived queries delegate unchanged', () async {
      // Given
      final active = categoryFixture(id: 'active');
      final archived = categoryFixture(
        id: 'archived',
        archivedAt: timestamp,
        modifiedAt: timestamp,
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([active]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([archived]),
      );

      // When
      final activeResult = await GetActiveCategoriesUseCase(repository)();
      final archivedResult = await GetArchivedCategoriesUseCase(repository)();

      // Then
      expect(activeResult.valueOrNull, [active]);
      expect(archivedResult.valueOrNull, [archived]);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}
