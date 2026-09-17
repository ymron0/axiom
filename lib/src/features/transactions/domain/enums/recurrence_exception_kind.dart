// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_exception_kind.mapper.dart';

/// Defines the behavior of one recurrence exception.
///
/// An exception always refers to one occurrence from the underlying recurrence
/// rule by its original scheduled date.
///
/// The exception either:
///
/// - skips that occurrence entirely; or
/// - replaces it with an occurrence whose date, transaction template, or both
///   differ from the normal series definition.
@MappableEnum()
enum RecurrenceExceptionKind {
  /// Prevents the scheduled occurrence from being generated.
  skip,

  /// Replaces the scheduled occurrence with a one-off variation.
  replacement,
}
