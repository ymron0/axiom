import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Resolves one tag by identity.
final class GetTagByIdUseCase {
  final TagRepository _repository;

  /// Creates a tag lookup use case.
  GetTagByIdUseCase(this._repository);

  /// Returns the tag identified by [id], or `null` when absent.
  Future<Result<Tag?, TagFailure>> call(TagId id) => _repository.getById(id);
}
