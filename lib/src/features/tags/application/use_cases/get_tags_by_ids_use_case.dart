import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Resolves several tag identities in one repository operation.
final class GetTagsByIdsUseCase {
  final TagRepository _repository;

  /// Creates a batch tag lookup use case.
  GetTagsByIdsUseCase(this._repository);

  /// Resolves [ids] while preserving repository batch semantics.
  Future<Result<BatchLookup<Tag, TagId>, TagFailure>> call(List<TagId> ids) {
    return _repository.getByIds(ids);
  }
}
