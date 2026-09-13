import 'package:axiom/src/application/services/delete_category_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/restore_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:axiom/src/features/categories/di/create_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/delete_category_service_provider.dart';
import 'package:axiom/src/features/categories/di/delete_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/restore_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/update_category_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../fixtures/features/categories/create_category_command_fixtures.dart' show createCategoryCommandFixture;
import '../../../../mocks/category_repository_mock.dart';



void main() {
  group('category providers', () {
    setUpAll(() {
      registerFallbackValue(categoryFixture(id: 'fallback'));
    });

    test('resolves the category repository, use cases, and deletion service', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(categoryRepositoryProvider);
      final dependencies = [
        container.read(createCategoryUseCaseProvider),
        container.read(getCategoryByIdUseCaseProvider),
        container.read(getCategoriesUseCaseProvider),
        container.read(updateCategoryUseCaseProvider),
        container.read(deleteCategoryUseCaseProvider),
        container.read(restoreCategoryUseCaseProvider),
        container.read(deleteCategoryServiceProvider),
      ];

      // Then
      expect(repository, isA<InMemoryCategoryRepositoryImpl>());
      expect(dependencies[0], isA<CreateCategoryUseCase>());
      expect(dependencies[1], isA<GetCategoryByIdUseCase>());
      expect(dependencies[2], isA<GetCategoriesUseCase>());
      expect(dependencies[3], isA<UpdateCategoryUseCase>());
      expect(dependencies[4], isA<DeleteCategoryUseCase>());
      expect(dependencies[5], isA<RestoreCategoryUseCase>());
      expect(dependencies[6], isA<DeleteCategoryService>());
    });

    test('injects the overridden repository into every category use case', () async {
      // Given
      final repository = MockCategoryRepository();
      final category = categoryFixture(id: 'groceries');
      final deleted = categoryFixture(
        id: 'deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(() => repository.create(any())).thenAnswer((_) async => const Success(null));
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success([category]));
      when(
        () => repository.getById(category.id),
      ).thenAnswer((_) async => Success(category));
      when(
        () => repository.getByParentId(category.id),
      ).thenAnswer((_) async => const Success(<Category>[]));
      when(() => repository.update(category)).thenAnswer((_) async => const Success(null));
      when(
        () => repository.delete(category.id),
      ).thenAnswer((_) async => Success(deleted));
      when(() => repository.restore(deleted)).thenAnswer((_) async => const Success(null));
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 1, 1))),
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
    });
  });
}
