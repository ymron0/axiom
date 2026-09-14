@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../fixtures/features/categories/create_category_command_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('CreateCategoryUseCase', () {
    late MockCategoryRepository repository;
    late CreateCategoryUseCase useCase;

    setUpAll(() {
      registerFallbackValue(categoryFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockCategoryRepository();
      useCase = CreateCategoryUseCase(
        repository: repository,
        clock: FixedClock(DateTime.utc(2026, 1, 2)),
      );
    });

    test('creates an active category with the injected clock', () async {
      // Given
      final command = createCategoryCommandFixture(name: 'Groceries');
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final category = result.valueOrNull!;
      expect(category.name, 'Groceries');
      expect(category.createdAt, DateTime.utc(2026, 1, 2));
      expect(category.modifiedAt, DateTime.utc(2026, 1, 2));
      expect(category.isDeleted, isFalse);
      verify(() => repository.create(category)).called(1);
    });

    test('does not create a child with an absent parent', () async {
      // Given
      final command = createCategoryCommandFixture(parentCategoryId: 'missing');
      when(
        () => repository.getById(command.parentCategoryId!),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
      verifyNever(() => repository.create(any()));
    });

    test('preserves persistence failures after valid creation', () async {
      // Given
      final command = createCategoryCommandFixture();
      const failure = CategoryAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
