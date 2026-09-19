import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_in_use_failure.mapper.dart';

/// Indicates that a tag is referenced by at least one persisted transaction.
@MappableClass()
final class TagInUseFailure extends Failure<TagInUseFailure>
    with TagInUseFailureMappable
    implements TagFailure {
  /// Creates a tag-in-use failure.
  const TagInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagInUse';

  @override
  TagInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
