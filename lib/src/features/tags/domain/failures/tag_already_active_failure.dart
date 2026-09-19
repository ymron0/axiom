import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_already_active_failure.mapper.dart';

/// Indicates that a tag expected to be deleted is already active.
@MappableClass()
final class TagAlreadyActiveFailure extends Failure<TagAlreadyActiveFailure>
    with TagAlreadyActiveFailureMappable
    implements TagFailure {
  /// Creates a tag-already-active failure.
  const TagAlreadyActiveFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagAlreadyActive';

  @override
  TagAlreadyActiveFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
