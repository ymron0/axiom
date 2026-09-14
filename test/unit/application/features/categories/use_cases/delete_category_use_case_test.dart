@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('DeleteCategoryUseCase', () {
    late MockCategoryRepository repository;
    late DeleteCategoryUseCase useCase;

    setUp(() {
      repository = MockCategoryRepository();
      useCase = DeleteCategoryUseCase(repository);
    });

    test('returns the repository deleted snapshot unchanged', () async {
      // Given
      final deleted = categoryFixture(
        id: 'groceries',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.delete(deleted.id),
      ).thenAnswer((_) async => Success(deleted));

      // When
      final result = await useCase(deleted.id);

      // Then
      expect(result.valueOrNull, same(deleted));
      verify(() => repository.delete(deleted.id)).called(1);
    });

    test('preserves repository failures', () async {
      // Given
      final category = categoryFixture(id: 'missing');
      const failure = CategoryNotFoundFailure(message: 'missing');
      when(() => repository.delete(category.id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(category.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
