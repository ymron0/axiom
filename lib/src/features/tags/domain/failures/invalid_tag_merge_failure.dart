import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_tag_merge_failure.mapper.dart';

/// Indicates that a requested tag merge is structurally invalid.
@MappableClass()
final class InvalidTagMergeFailure extends Failure<InvalidTagMergeFailure>
    with InvalidTagMergeFailureMappable
    implements TagFailure {
  /// Creates an invalid-tag-merge failure.
  const InvalidTagMergeFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.invalidTagMerge';

  @override
  InvalidTagMergeFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
