import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_repository_failure.mapper.dart';

/// Indicates that a tag repository operation could not complete.
@MappableClass()
final class TagRepositoryFailure extends Failure<TagRepositoryFailure>
    with TagRepositoryFailureMappable
    implements TagFailure {
  /// Creates a tag repository failure with optional details.
  const TagRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.repository';

  @override
  TagRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
