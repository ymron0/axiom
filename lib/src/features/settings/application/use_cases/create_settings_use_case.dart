import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';

/// Creates the application's initial settings.
///
/// The supplied [Settings] must already satisfy all domain invariants.
///
/// Cross-feature validation does not belong here. For example, validating that
/// `valuationAssetId` refers to a currency must be performed by the owning
/// orchestration workflow before this use case is invoked.
///
/// The repository determines the failure returned when settings already exist.
class CreateSettingsUseCase {
  /// Creates a use case backed by [repository].
  const CreateSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  /// Persists [settings] as the application's settings.
  Future<Result<Settings, BaseFailure>> call(Settings settings) {
    return _repository.create(settings);
  }
}
