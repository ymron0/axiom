import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_persistence_failure.mapper.dart';

/// Indicates that tag persistence failed unexpectedly.
@MappableClass()
final class TagPersistenceFailure extends Failure<TagPersistenceFailure>
    with TagPersistenceFailureMappable
    implements TagFailure {
  /// Creates a tag-persistence failure.
  const TagPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagPersistence';

  @override
  TagPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
