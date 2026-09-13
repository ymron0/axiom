import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('GetCategoriesUseCase', () {
    late MockCategoryRepository repository;
    late GetCategoriesUseCase useCase;

    setUp(() {
      repository = MockCategoryRepository();
      useCase = GetCategoriesUseCase(repository);
    });

    test('returns all repository categories unchanged', () async {
      // Given
      final categories = [categoryFixture(id: 'groceries')];
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Category>>(categories));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(categories));
      verify(() => repository.getAll()).called(1);
    });

    test('preserves repository failures', () async {
      // Given
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
