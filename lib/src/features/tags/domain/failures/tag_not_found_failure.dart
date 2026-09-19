import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_not_found_failure.mapper.dart';

/// Indicates that an expected tag does not exist.
@MappableClass()
final class TagNotFoundFailure extends Failure<TagNotFoundFailure>
    with TagNotFoundFailureMappable
    implements TagFailure {
  /// Creates a tag-not-found failure.
  const TagNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagNotFound';

  @override
  TagNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
