import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/commands/create_category_command.dart';
import 'package:axiom/src/features/categories/application/services/category_hierarchy_validation.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Creates and persists a new active category.
final class CreateCategoryUseCase {
  /// Creates a use case with its repository and time source.
  const CreateCategoryUseCase({
    required CategoryRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CategoryRepository _repository;
  final Clock _clock;

  /// Creates and persists a category from [command].
  Future<Result<Category, CategoryFailure>> call(
    CreateCategoryCommand command,
  ) async {
    final hierarchyResult = await CategoryHierarchyValidation.validateParent(
      repository: _repository,
      categoryId: null,
      parentCategoryId: command.parentCategoryId,
      kind: command.kind,
    );
    if (hierarchyResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final category = Category.create(
      name: command.name,
      parentCategoryId: command.parentCategoryId,
      kind: command.kind,
      budgets: command.budgets,
      icon: command.icon,
      color: command.color,
      sortOrder: command.sortOrder,
      clock: _clock,
    );
    final createResult = await _repository.create(category);

    return createResult.when<Result<Category, CategoryFailure>>(
      success: (_) => Success(category),
      failure: (failure) => failure,
    );
  }
}
