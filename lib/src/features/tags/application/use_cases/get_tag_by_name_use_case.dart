import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Resolves a tag by its normalized name.
final class GetTagByNameUseCase {
  final TagRepository _repository;

  /// Creates a tag-name lookup use case.
  GetTagByNameUseCase(this._repository);

  /// Returns the tag matching [name], or `null` when none exists.
  Future<Result<Tag?, TagFailure>> call(String name) {
    return _repository.getByName(name);
  }
}
