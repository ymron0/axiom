import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_already_exists_failure.mapper.dart';

/// Indicates that a jar conflicts with an existing persisted jar.
@MappableClass()
final class JarAlreadyExistsFailure
    extends Failure<JarAlreadyExistsFailure>
    with JarAlreadyExistsFailureMappable
    implements JarFailure {
  /// Creates a jar-already-exists failure.
  const JarAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarAlreadyExists';

  @override
  JarAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}