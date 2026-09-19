import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_name_already_exists_failure.mapper.dart';

/// Indicates that another tag uses the same normalized name.
@MappableClass()
final class TagNameAlreadyExistsFailure
    extends Failure<TagNameAlreadyExistsFailure>
    with TagNameAlreadyExistsFailureMappable
    implements TagFailure {
  /// Creates a tag-name-already-exists failure.
  const TagNameAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.tagNameAlreadyExists';

  @override
  TagNameAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
