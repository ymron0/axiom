// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'jar_kind.mapper.dart';

/// Describes the financial purpose and lifecycle semantics of a jar.
@MappableEnum()
enum JarKind {
  /// Accumulates money toward a finite objective.
  ///
  /// Examples include a new car, holiday, or house deposit.
  savingsGoal,

  /// Accumulates money for expected future spending and may be reused.
  ///
  /// Examples include annual insurance, vehicle maintenance, or gifts.
  sinkingFund,

  /// Keeps money aside indefinitely or until needed.
  ///
  /// Examples include an emergency fund or general cash reserve.
  reserve,
}
