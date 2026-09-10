// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_state.mapper.dart';

/// Describes the lifecycle state of a transaction.
///
/// ## Semantics
///
/// A transaction is either [planned] or [actual].
///
/// A planned transaction represents an expected transaction that has not yet
/// occurred. An actual transaction represents a transaction that has occurred
/// and forms part of the actual financial record.
///
/// This state expresses domain lifecycle meaning only. It does not represent
/// UI state, presentation styling, reconciliation status, or approval state.
@MappableEnum()
enum TransactionState {
  /// An expected transaction that has not yet occurred.
  ///
  /// Planned transactions may be used for projections and forecasting but do
  /// not represent actual financial activity.
  planned,

  /// A transaction that has occurred and forms part of the actual financial
  /// record.
  actual,
}
