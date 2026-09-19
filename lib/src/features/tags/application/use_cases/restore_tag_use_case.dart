import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Restores a caller-retained deleted tag snapshot.
final class RestoreTagUseCase {
  final TagRepository _repository;

  /// Creates a tag restoration use case.
  RestoreTagUseCase(this._repository);

  /// Restores [tag].
  Future<Result<void, TagFailure>> call(Tag tag) => _repository.restore(tag);
}
