import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_already_deleted_failure.mapper.dart';

/// Indicates that a tag is already marked as deleted.
@MappableClass()
final class TagAlreadyDeletedFailure extends Failure<TagAlreadyDeletedFailure>
    with TagAlreadyDeletedFailureMappable
    implements TagFailure {
  /// Creates a tag-already-deleted failure.
  const TagAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagAlreadyDeleted';

  @override
  TagAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
