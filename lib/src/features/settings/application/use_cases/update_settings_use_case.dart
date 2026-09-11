import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';

/// Updates the application's persisted settings.
///
/// This use case performs only settings-feature application behavior and does
/// not depend on other features.
///
/// Any field that is immutable after initialization, such as
/// `valuationAssetId`, must remain protected by the appropriate domain or
/// application invariant rather than being implicitly made mutable by this
/// use case.
///
/// The repository determines the failure returned when settings do not exist.
final class UpdateSettingsUseCase {
  /// Creates a use case backed by [repository].
  const UpdateSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  /// Replaces the persisted settings with [settings].
  Future<Result<Settings, BaseFailure>> call(Settings settings) {
    return _repository.update(settings);
  }
}
