import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_already_archived_failure.mapper.dart';

/// Indicates that a tag is already archived.
@MappableClass()
final class TagAlreadyArchivedFailure extends Failure<TagAlreadyArchivedFailure>
    with TagAlreadyArchivedFailureMappable
    implements TagFailure {
  /// Creates a tag-already-archived failure.
  const TagAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagAlreadyArchived';

  @override
  TagAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
