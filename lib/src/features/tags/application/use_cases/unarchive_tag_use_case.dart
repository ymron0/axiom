import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Makes an archived tag available for new assignments again.
final class UnarchiveTagUseCase {
  final TagRepository _repository;
  final Clock _clock;

  /// Creates a tag unarchival use case.
  const UnarchiveTagUseCase({
    required TagRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Unarchives the tag identified by [id].
  Future<Result<Tag, TagFailure>> call(TagId id) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
