// coverage:ignore-file

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_valuation_currency_change_not_allowed_failure.dart';

/// Persists the application's single settings record.
abstract interface class SettingsRepository {
  /// Returns the initial settings, or `null` before setup is complete.
  Future<Result<Settings?, SettingsFailure>> get();

  /// Persists settings during initial setup.
  ///
  /// Returns [SettingsAlreadyInitializedFailure] when settings already exist.
  Future<Result<Settings, SettingsFailure>> create(Settings settings);

  /// Replaces the existing settings after initial setup.
  ///
  /// The valuation currency is immutable after initialization.
  ///
  /// Returns [SettingsNotInitializedFailure] when no settings record exists.
  ///
  /// Returns [SettingsValuationCurrencyChangeNotAllowedFailure] when
  /// [Settings.valuationCurrencyId] differs from the persisted value.
  Future<Result<Settings, SettingsFailure>> update(Settings settings);
}
