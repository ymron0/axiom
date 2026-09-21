// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_occurrence_deletion_mode.mapper.dart';

/// Defines what happens after a generated recurrence occurrence is deleted.
@MappableEnum()
enum TransactionOccurrenceDeletionMode {
  /// Deletes the generated transaction and permanently skips its recurrence
  /// slot.
  skip,

  /// Deletes the generated transaction and immediately generates a new
  /// transaction for the same recurrence slot.
  regenerate,

  /// Deletes and skips the recurrence slot, while extending a finite series by
  /// one recurrence slot so the skipped occurrence is compensated at the end.
  skipAndAppend,
}
