import 'package:axiom/src/core/presentation/formatting/app_date_formatter.dart';
import 'package:axiom/src/core/presentation/formatting/app_number_formatter.dart';
import 'package:flutter/material.dart';

/// Formatting services derived from the active presentation environment.
///
/// ## Semantics
///
/// The formatter always uses the current application locale and time display
/// preference.
///
/// ## Contract
///
/// Obtain a formatter from [of] inside widget presentation code.
///
/// Do not cache an instance across locale changes. Rebuilds should resolve a
/// new formatter from the current [BuildContext].
final class PresentationFormatters {
  /// Locale-aware numeric formatter.
  final AppNumberFormatter numbers;

  /// Locale-aware date/time formatter.
  final AppDateFormatter dates;

  /// Creates a formatter collection.
  const PresentationFormatters({required this.numbers, required this.dates});

  /// Resolves formatting services from the current presentation context.
  factory PresentationFormatters.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final mediaQuery = MediaQuery.of(context);

    return PresentationFormatters(
      numbers: AppNumberFormatter(localeName: locale.toLanguageTag()),
      dates: AppDateFormatter(
        localizations: MaterialLocalizations.of(context),
        alwaysUse24HourFormat: mediaQuery.alwaysUse24HourFormat,
      ),
    );
  }
}
