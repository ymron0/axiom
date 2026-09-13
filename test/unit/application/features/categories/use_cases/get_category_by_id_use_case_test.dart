import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('GetCategoryByIdUseCase', () {
    late MockCategoryRepository repository;
    late GetCategoryByIdUseCase useCase;

    setUp(() {
      repository = MockCategoryRepository();
      useCase = GetCategoryByIdUseCase(repository);
    });

    test('returns the repository category including an absent result', () async {
      // Given
      final category = categoryFixture(id: 'groceries');
      when(
        () => repository.getById(category.id),
      ).thenAnswer((_) async => Success(category));

      // When
      final result = await useCase(category.id);

      // Then
      expect(result.valueOrNull, same(category));
      verify(() => repository.getById(category.id)).called(1);
    });

    test('preserves repository failures', () async {
      // Given
      final category = categoryFixture(id: 'missing');
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(() => repository.getById(category.id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(category.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
