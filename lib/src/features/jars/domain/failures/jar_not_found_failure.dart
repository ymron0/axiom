import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_not_found_failure.mapper.dart';

/// Indicates that an expected jar does not exist.
@MappableClass()
final class JarNotFoundFailure extends Failure<JarNotFoundFailure>
    with JarNotFoundFailureMappable
    implements JarFailure {
  /// Creates a jar-not-found failure.
  const JarNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarNotFound';

  @override
  JarNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
