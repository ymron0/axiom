import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/invalid_tag_name_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';

/// Creates and persists a new active tag.
final class CreateTagUseCase {
  final TagRepository _repository;
  final Clock _clock;

  /// Creates a tag creation use case.
  const CreateTagUseCase({
    required TagRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Creates a normalized tag named [name].
  Future<Result<Tag, TagFailure>> call(String name) async {
    final Tag tag;

    try {
      tag = Tag.create(name: name, clock: _clock);
    } on ArgumentError catch (error) {
      if (error.name != 'name') {
        rethrow;
      }

      return InvalidTagNameFailure(message: error.message.toString());
    }

    final result = await _repository.create(tag);

    return result.when<Result<Tag, TagFailure>>(
      success: (_) => Success(tag),
      failure: (failure) => failure,
    );
  }
}
