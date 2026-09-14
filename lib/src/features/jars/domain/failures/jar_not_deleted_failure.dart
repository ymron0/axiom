import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_not_deleted_failure.mapper.dart';

/// Indicates that an operation requiring a deleted jar received a persisted jar.
@MappableClass()
final class JarNotDeletedFailure
    extends Failure<JarNotDeletedFailure>
    with JarNotDeletedFailureMappable
    implements JarFailure {
  /// Creates a jar-not-deleted failure.
  const JarNotDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarNotDeleted';

  @override
  JarNotDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}