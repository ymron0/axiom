import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_repository_failure.mapper.dart';

/// Indicates that a jar repository operation could not complete.
@MappableClass()
final class JarRepositoryFailure extends Failure<JarRepositoryFailure>
    with JarRepositoryFailureMappable
    implements JarFailure {
  /// Creates a jar repository failure with optional details.
  const JarRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.repository';

  @override
  JarRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
