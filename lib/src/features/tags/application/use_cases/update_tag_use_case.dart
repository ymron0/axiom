import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Persists a complete replacement tag snapshot.
final class UpdateTagUseCase {
  final TagRepository _repository;

  /// Creates a tag update use case.
  UpdateTagUseCase(this._repository);

  /// Persists [tag].
  Future<Result<void, TagFailure>> call(Tag tag) => _repository.update(tag);
}
