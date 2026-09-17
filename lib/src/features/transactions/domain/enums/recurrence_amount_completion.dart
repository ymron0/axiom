// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_amount_completion.mapper.dart';

/// Defines how an amount-based recurrence handles its final occurrence.
///
/// An amount target may fall between two normal recurrence amounts.
///
/// For example, when the target is CHF 1,000 and each normal occurrence is
/// CHF 120, eight occurrences total CHF 960. The ninth occurrence can either:
///
/// - remain CHF 120, producing a final cumulative amount of CHF 1,080; or
/// - be reduced to CHF 40, producing exactly CHF 1,000.
///
/// This enum defines which of those behaviors applies.
@MappableEnum()
enum RecurrenceAmountCompletion {
  /// Keeps the normal amount of the final occurrence.
  ///
  /// The cumulative amount may therefore exceed the configured target.
  ///
  /// Example:
  ///
  /// ```text
  /// Target:             CHF 1,000
  /// Accumulated:        CHF   960
  /// Normal occurrence:  CHF   120
  /// Final occurrence:   CHF   120
  /// Final total:        CHF 1,080
  /// ```
  fullOccurrence,

  /// Reduces the final occurrence to the exact remaining amount.
  ///
  /// The cumulative amount therefore finishes exactly on the configured
  /// target.
  ///
  /// Example:
  ///
  /// ```text
  /// Target:             CHF 1,000
  /// Accumulated:        CHF   960
  /// Normal occurrence:  CHF   120
  /// Final occurrence:   CHF    40
  /// Final total:        CHF 1,000
  /// ```
  exactTarget,
}
