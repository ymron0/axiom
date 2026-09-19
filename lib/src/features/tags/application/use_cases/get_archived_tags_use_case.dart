import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Returns archived tags.
final class GetArchivedTagsUseCase {
  final TagRepository _repository;

  /// Creates an archived-tag query use case.
  GetArchivedTagsUseCase(this._repository);

  /// Returns all archived tags.
  Future<Result<List<Tag>, TagFailure>> call() => _repository.getArchived();
}
