import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_persistence_failure.mapper.dart';

/// Indicates that jar persistence could not complete successfully.
///
/// This failure represents storage-level problems exposed through the Jars
/// domain failure contract.
///
/// Infrastructure-specific failures and exceptions must not escape through
/// `JarRepository`. Persistent repository implementations translate expected
/// storage problems into this failure instead.
///
/// Examples include:
///
/// - Sembast database failures,
/// - file-system failures,
/// - malformed persisted jar records,
/// - persisted jar records that cannot be reconstructed according to the
///   current domain invariants.
///
/// Programmer errors and violated internal assumptions are deliberately not
/// translated into this failure and must continue to propagate normally.
@MappableClass()
final class JarPersistenceFailure extends Failure<JarPersistenceFailure>
    with JarPersistenceFailureMappable
    implements JarFailure {
  /// Creates a jar-persistence failure with optional details.
  const JarPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.persistence';

  @override
  JarPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
