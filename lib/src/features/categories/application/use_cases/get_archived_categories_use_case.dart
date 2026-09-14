import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Returns persisted categories that are archived.
final class GetArchivedCategoriesUseCase {
  /// Creates a use case backed by [repository].
  GetArchivedCategoriesUseCase(this._repository);

  final CategoryRepository _repository;

  /// Returns every archived persisted category.
  Future<Result<List<Category>, CategoryFailure>> call() {
    return _repository.getArchived();
  }
}
