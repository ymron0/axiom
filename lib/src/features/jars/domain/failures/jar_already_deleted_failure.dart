import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_already_deleted_failure.mapper.dart';

/// Indicates that a jar is already marked as deleted.
@MappableClass()
final class JarAlreadyDeletedFailure extends Failure<JarAlreadyDeletedFailure>
    with JarAlreadyDeletedFailureMappable
    implements JarFailure {
  /// Creates a jar-already-deleted failure.
  const JarAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarAlreadyDeleted';

  @override
  JarAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
