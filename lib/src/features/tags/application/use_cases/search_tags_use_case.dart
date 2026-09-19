import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Searches persisted tags by normalized display name.
final class SearchTagsUseCase {
  final TagRepository _repository;

  /// Creates a tag search use case.
  SearchTagsUseCase(this._repository);

  /// Returns tags matching [query].
  Future<Result<List<Tag>, TagFailure>> call(String query) {
    return _repository.search(query);
  }
}
