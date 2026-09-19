import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived tag received an active tag.
@MappableClass()
final class TagNotArchivedFailure extends Failure<TagNotArchivedFailure>
    with TagNotArchivedFailureMappable
    implements TagFailure {
  /// Creates a tag-not-archived failure.
  const TagNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagNotArchived';

  @override
  TagNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
