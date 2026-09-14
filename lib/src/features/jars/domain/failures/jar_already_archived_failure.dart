import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_already_archived_failure.mapper.dart';

/// Indicates that a jar is already archived.
@MappableClass()
final class JarAlreadyArchivedFailure extends Failure<JarAlreadyArchivedFailure>
    with JarAlreadyArchivedFailureMappable
    implements JarFailure {
  /// Creates a jar-already-archived failure.
  const JarAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarAlreadyArchived';

  @override
  JarAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
