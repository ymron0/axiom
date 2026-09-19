import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_already_exists_failure.mapper.dart';

/// Indicates that a tag with the same identity already exists.
@MappableClass()
final class TagAlreadyExistsFailure extends Failure<TagAlreadyExistsFailure>
    with TagAlreadyExistsFailureMappable
    implements TagFailure {
  /// Creates a tag-already-exists failure.
  const TagAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagAlreadyExists';

  @override
  TagAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
