// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'planned_transaction_generation_horizon.mapper.dart';

/// Defines how far ahead planned recurring transactions should be materialized.
///
/// This setting controls the user's preferred generation horizon.
///
/// It does not control the lifetime of a transaction series. A series may
/// continue beyond this horizon or have no configured end at all.
///
/// The application additionally enforces an absolute rolling two-year
/// generation limit regardless of this setting.
@MappableEnum()
enum PlannedTransactionGenerationHorizon {
  /// Materializes only the next eligible occurrence.
  nextOccurrence,

  /// Materializes eligible occurrences through one year from today.
  oneYear,

  /// Materializes eligible occurrences through two years from today.
  twoYears,
}
