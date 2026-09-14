@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:axiom/src/features/categories/di/create_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/delete_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/restore_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/update_category_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';
import '../../../../../fixtures/features/categories/create_category_command_fixtures.dart'
    show createCategoryCommandFixture;

void main() {
  group('category use-case providers', () {
    setUpAll(() {
      registerFallbackValue(categoryFixture(id: 'fallback'));
    });

    test(
      'injects the overridden repository into every category use case',
      () async {
        // Given
        final repository = MockCategoryRepository();
        final category = categoryFixture(id: 'groceries');
        final deleted = categoryFixture(
          id: 'deleted',
          deletedAt: DateTime.utc(2026, 1, 2),
        );
        when(
          () => repository.create(any()),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repository.getAll(),
        ).thenAnswer((_) async => Success([category]));
        when(
          () => repository.getById(category.id),
        ).thenAnswer((_) async => Success(category));
        when(
          () => repository.getByParentId(category.id),
        ).thenAnswer((_) async => const Success(<Category>[]));
        when(
          () => repository.update(category),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repository.delete(category.id),
        ).thenAnswer((_) async => Success(deleted));
        when(
          () => repository.restore(deleted),
        ).thenAnswer((_) async => const Success(null));
        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(repository),
            clockProvider.overrideWithValue(
              FixedClock(DateTime.utc(2026, 1, 1)),
            ),
          ],
        );
        addTearDown(container.dispose);

        // When
        final created = await container.read(createCategoryUseCaseProvider)(
          createCategoryCommandFixture(),
        );
        await container.read(getCategoryByIdUseCaseProvider)(category.id);
        await container.read(getCategoriesUseCaseProvider)();
        await container.read(updateCategoryUseCaseProvider)(category);
        await container.read(deleteCategoryUseCaseProvider)(category.id);
        await container.read(restoreCategoryUseCaseProvider)(deleted);

        // Then
        verify(() => repository.create(created.valueOrNull!)).called(1);
        verify(() => repository.getById(category.id)).called(1);
        verify(() => repository.getAll()).called(1);
        verify(() => repository.getByParentId(category.id)).called(1);
        verify(() => repository.update(category)).called(1);
        verify(() => repository.delete(category.id)).called(1);
        verify(() => repository.restore(deleted)).called(1);
      },
    );
  });
}
