import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_not_assignable_failure.mapper.dart';

/// Indicates that a tag cannot be newly assigned to a transaction.
///
/// Archived tags remain valid historical references but cannot be attached to
/// new transactions or newly added to existing transactions.
@MappableClass()
final class TagNotAssignableFailure extends Failure<TagNotAssignableFailure>
    with TagNotAssignableFailureMappable
    implements TagFailure {
  /// Creates a tag-not-assignable failure.
  const TagNotAssignableFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagNotAssignable';

  @override
  TagNotAssignableFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
