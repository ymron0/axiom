import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_tag_name_failure.mapper.dart';

/// Indicates that a supplied tag name is invalid.
@MappableClass()
final class InvalidTagNameFailure extends Failure<InvalidTagNameFailure>
    with InvalidTagNameFailureMappable
    implements TagFailure {
  /// Creates an invalid-tag-name failure.
  const InvalidTagNameFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'tags.invalidTagName';

  @override
  InvalidTagNameFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
