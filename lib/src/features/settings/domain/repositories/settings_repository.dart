// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';

/// Persists the application's single settings record.
abstract interface class SettingsRepository {
  /// Returns the initial settings, or `null` before setup is complete.
  Future<Result<Settings?, BaseFailure>> get();

  /// Persists settings during initial setup.
  ///
  /// Implementations must reject a second record. There is deliberately no
  /// update operation during initial setup.
  Future<Result<Settings, BaseFailure>> create(Settings settings);

  /// Replaces the existing settings after initial setup.
  ///
  /// Implementations must reject the operation when no settings record
  /// exists.
  Future<Result<Settings, BaseFailure>> update(Settings settings);
}
