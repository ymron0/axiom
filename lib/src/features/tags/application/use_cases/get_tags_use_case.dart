import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Returns all persisted tags.
final class GetTagsUseCase {
  final TagRepository _repository;

  /// Creates a tag query use case.
  GetTagsUseCase(this._repository);

  /// Returns all persisted tags, including archived tags.
  Future<Result<List<Tag>, TagFailure>> call() => _repository.getAll();
}
