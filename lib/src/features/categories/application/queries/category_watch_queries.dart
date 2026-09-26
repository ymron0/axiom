import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Reactive category queries intended for presentation reads.
final class CategoryWatchQueries {
  final CategoryRepository _repository;

  /// Creates reactive category queries backed by [repository].
  CategoryWatchQueries(this._repository);

  /// Watches every persisted category.
  Stream<Result<List<Category>, CategoryFailure>> all() {
    return _repository.watchAll();
  }

  /// Watches active categories.
  Stream<Result<List<Category>, CategoryFailure>> active() {
    return _repository.watchActive();
  }

  /// Watches archived categories.
  Stream<Result<List<Category>, CategoryFailure>> archived() {
    return _repository.watchArchived();
  }

  /// Watches one category by identity.
  Stream<Result<Category?, CategoryFailure>> byId(CategoryId id) {
    return _repository.watchById(id);
  }
}
