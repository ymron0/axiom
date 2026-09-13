import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Retrieves an active persisted category by identifier.
class GetCategoryByIdUseCase {
  /// Creates a use case backed by [repository].
  GetCategoryByIdUseCase(this._repository);

  final CategoryRepository _repository;

  /// Returns the active category matching [id], or `null` when absent.
  Future<Result<Category?, CategoryFailure>> call(CategoryId id) {
    return _repository.getById(id);
  }
}
