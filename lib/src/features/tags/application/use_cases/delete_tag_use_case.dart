import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Physically deletes a tag after cross-feature checks have succeeded.
final class DeleteTagUseCase {
  final TagRepository _repository;

  /// Creates a tag deletion use case.
  DeleteTagUseCase(this._repository);

  /// Deletes the tag identified by [id].
  Future<Result<Tag, TagFailure>> call(TagId id) => _repository.delete(id);
}
