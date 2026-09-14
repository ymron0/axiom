import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_in_use_failure.mapper.dart';

/// Indicates that a jar cannot be deleted because transactions reference it.
///
/// Archiving is still permitted while a jar is referenced by transactions.
@MappableClass()
final class JarInUseFailure extends Failure<JarInUseFailure>
    with JarInUseFailureMappable
    implements JarFailure {
  /// Creates a jar-in-use failure.
  const JarInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'jars.jarInUse';

  @override
  JarInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
