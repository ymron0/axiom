import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'unexpected_persistence_failure.mapper.dart';

/// Indicates that persistence failed without a more specific failure type.
///
/// Example:
/// ```dart
/// const failure = UnexpectedPersistenceFailure(
///   message: 'The asset store could not be read.',
/// );
/// ```
@MappableClass()
final class UnexpectedPersistenceFailure
    extends Failure<UnexpectedPersistenceFailure>
    with UnexpectedPersistenceFailureMappable {
  /// Creates an unexpected persistence failure with optional details.
  const UnexpectedPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.unexpected';

  /// Returns this failure as its declared failure type.
  @override
  UnexpectedPersistenceFailure get failureOrNull => this;

  /// Returns the stable identifier for this failure kind.
  @override
  String get type => typeId;
}
