import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:flutter/material.dart';

/// Locale-aware formatter for calendar dates and instants.
///
/// This formatter delegates date and time representation to Flutter's active
/// [MaterialLocalizations].
///
/// ## Semantics
///
/// [CalendarDate] values are date-only values and are never timezone shifted.
///
/// [DateTime] values represent instants and are converted to local device time
/// before presentation.
///
/// ## Contract
///
/// Supported locale configuration remains owned by the root application.
/// This formatter only consumes the already-active localization.
///
/// Business calculations must never depend on the strings produced here.
final class AppDateFormatter {
  final MaterialLocalizations _localizations;
  final bool _alwaysUse24HourFormat;

  /// Creates a date formatter backed by Material localization.
  const AppDateFormatter({
    required MaterialLocalizations localizations,
    required bool alwaysUse24HourFormat,
  }) : _localizations = localizations, // ignore: prefer_initializing_formals
       _alwaysUse24HourFormat = // ignore: prefer_initializing_formals
           alwaysUse24HourFormat;

  /// Formats a domain calendar date in medium localized form.
  String calendarDate(CalendarDate value) {
    return _localizations.formatMediumDate(value.toDateTimeUtc());
  }

  /// Formats a domain calendar date in compact localized form.
  String shortCalendarDate(CalendarDate value) {
    return _localizations.formatShortDate(value.toDateTimeUtc());
  }

  /// Formats the month and year represented by [value].
  String monthYear(CalendarDate value) {
    return _localizations.formatMonthYear(value.toDateTimeUtc());
  }

  /// Formats the local date corresponding to [value].
  String date(DateTime value) {
    final local = value.toLocal();

    return _localizations.formatMediumDate(local);
  }

  /// Formats the local time corresponding to [value].
  String time(DateTime value) {
    final local = value.toLocal();

    return _localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: _alwaysUse24HourFormat,
    );
  }

  /// Formats the local date and time corresponding to [value].
  String dateTime(DateTime value) {
    return '${date(value)} ${time(value)}';
  }
}
