import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Archives a category and its sub-categories without deleting them.
final class ArchiveCategoryUseCase {
  /// Creates a use case with its repository and canonical time source.
  const ArchiveCategoryUseCase({
    required CategoryRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CategoryRepository _repository;
  final Clock _clock;

  /// Archives [id] and all of its direct child categories atomically.
  Future<Result<Category, CategoryFailure>> call(CategoryId id) {
    return _repository.archive(id, _clock.nowUtc);
  }
}
