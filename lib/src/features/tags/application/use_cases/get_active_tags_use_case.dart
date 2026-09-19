import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Returns tags available for new assignments.
final class GetActiveTagsUseCase {
  final TagRepository _repository;

  /// Creates an active-tag query use case.
  GetActiveTagsUseCase(this._repository);

  /// Returns all non-archived tags.
  Future<Result<List<Tag>, TagFailure>> call() => _repository.getActive();
}
