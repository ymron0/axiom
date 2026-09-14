import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived jar received an
/// unarchived jar.
@MappableClass()
final class JarNotArchivedFailure
    extends Failure<JarNotArchivedFailure>
    with JarNotArchivedFailureMappable
    implements JarFailure {
  /// Creates a jar-not-archived failure.
  const JarNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarNotArchived';

  @override
  JarNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}