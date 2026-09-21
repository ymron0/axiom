import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_occurrence_origin.mapper.dart';

/// Identifies the recurrence slot from which a transaction was generated.
///
/// [seriesId] identifies the owning transaction series.
///
/// [scheduledOn] is the original recurrence date produced by the series rule.
/// It remains unchanged when a recurrence exception moves the effective
/// transaction date.
@MappableClass()
final class TransactionOccurrenceOrigin
    with TransactionOccurrenceOriginMappable {
  /// Transaction series that generated the transaction.
  final TransactionSeriesId seriesId;

  /// Original scheduled recurrence date.
  final CalendarDate scheduledOn;

  /// Creates recurrence-origin metadata for a generated transaction.
  const TransactionOccurrenceOrigin({
    required this.seriesId,
    required this.scheduledOn,
  });
}
