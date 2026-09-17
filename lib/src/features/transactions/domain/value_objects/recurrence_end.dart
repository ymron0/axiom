import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_end.mapper.dart';

/// Defines optional termination conditions for a recurrence.
///
/// A recurrence may terminate:
///
/// - on an inclusive calendar date through [until];
/// - after a maximum number of occurrences through [count];
/// - after reaching a cumulative monetary target through [amount]; or
/// - when the first of several configured conditions is reached.
///
/// At least one termination condition must be supplied.
///
/// ## Date semantics
///
/// [until] is inclusive.
///
/// An occurrence scheduled exactly on [until] is therefore permitted.
///
/// ## Count semantics
///
/// [count] includes the first occurrence.
///
/// For example:
///
/// ```text
/// count = 1
/// ```
///
/// means that only occurrence index `0` is permitted.
///
/// ## Amount semantics
///
/// [amount] is evaluated against cumulative financial progress and therefore
/// cannot be evaluated by calendar recurrence calculation alone.
///
/// [allows] consequently evaluates only [until] and [count]. Amount-based
/// termination must additionally be evaluated by the occurrence-generation
/// workflow using [RecurrenceAmountEnd].
///
/// For an amount-only recurrence, [allows] remains `true` indefinitely because
/// the calendar rule itself has no knowledge of accumulated financial amounts.
///
/// ## Combined termination
///
/// When more than one condition exists, the recurrence terminates when any
/// configured condition is reached first.
///
/// For example:
///
/// ```text
/// until: 2027-12-31
/// count: 24
/// amount: CHF 10,000
/// ```
///
/// means that generation stops at whichever boundary applies first.
@MappableClass()
final class RecurrenceEnd with RecurrenceEndMappable {
  /// Inclusive final calendar date permitted by this recurrence.
  final CalendarDate? until;

  /// Maximum number of occurrences, including the first occurrence.
  final int? count;

  /// Optional cumulative monetary target.
  final RecurrenceAmountEnd? amount;

  /// Creates recurrence termination conditions.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - no termination condition is supplied; or
  /// - [count] is less than one.
  @MappableConstructor()
  RecurrenceEnd({this.until, this.count, this.amount}) {
    if (until == null && count == null && amount == null) {
      throw ArgumentError(
        'A recurrence end must define an until date, an occurrence count, '
        'an amount target, or a combination of them.',
      );
    }

    if (count != null && count! < 1) {
      throw ArgumentError.value(
        count,
        'count',
        'Recurrence occurrence count must be at least one.',
      );
    }
  }

  /// Whether the date and occurrence index are permitted by this end rule.
  ///
  /// [occurrenceIndex] is zero based.
  ///
  /// This method deliberately does not evaluate [amount], because doing so
  /// requires accumulated financial progress that does not belong to the
  /// calendar recurrence rule.
  ///
  /// Throws a [RangeError] when [occurrenceIndex] is negative.
  bool allows({required CalendarDate date, required int occurrenceIndex}) {
    if (occurrenceIndex < 0) {
      throw RangeError.range(
        occurrenceIndex,
        0,
        null,
        'occurrenceIndex',
        'Occurrence index cannot be negative.',
      );
    }

    final withinDate = until == null || date.isOnOrBefore(until!);
    final withinCount = count == null || occurrenceIndex < count!;

    return withinDate && withinCount;
  }

  /// Whether this recurrence has a cumulative monetary termination condition.
  bool get hasAmountTarget => amount != null;
}
