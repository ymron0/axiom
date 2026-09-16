@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/archive_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_active_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_archived_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/unarchive_category_use_case.dart';
import 'package:axiom/src/features/categories/di/archive_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:axiom/src/features/categories/di/get_active_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_archived_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/unarchive_category_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('category archival use-case providers', () {
    test('resolves archival use cases with the default repository', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );
      final lifecycleService = container.read(databaseLifecycleServiceProvider);
      addTearDown(() async {
        await lifecycleService.close();
        container.dispose();
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      // Then
      expect((await lifecycleService.open()).isSuccess, isTrue);
      expect(container.read(archiveCategoryUseCaseProvider), isA<ArchiveCategoryUseCase>());
      expect(container.read(unarchiveCategoryUseCaseProvider), isA<UnarchiveCategoryUseCase>());
      expect(container.read(getActiveCategoriesUseCaseProvider), isA<GetActiveCategoriesUseCase>());
      expect(container.read(getArchivedCategoriesUseCaseProvider), isA<GetArchivedCategoriesUseCase>());
    });

    test('forwards overridden dependencies', () async {
      // Given
      final repository = MockCategoryRepository();
      final category = categoryFixture(id: 'category');
      when(() => repository.archive(category.id, timestamp)).thenAnswer(
        (_) async => Success(category),
      );
      when(() => repository.unarchive(category.id, timestamp)).thenAnswer(
        (_) async => Success(category),
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([category]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([category]),
      );
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);

      // When
      await container.read(archiveCategoryUseCaseProvider)(category.id);
      await container.read(unarchiveCategoryUseCaseProvider)(category.id);
      await container.read(getActiveCategoriesUseCaseProvider)();
      await container.read(getArchivedCategoriesUseCaseProvider)();

      // Then
      verify(() => repository.archive(category.id, timestamp)).called(1);
      verify(() => repository.unarchive(category.id, timestamp)).called(1);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'category-archival-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
