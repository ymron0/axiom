import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';

/// Retrieves the application's persisted settings.
///
/// This use case contains no cross-feature logic. It delegates retrieval to
/// [SettingsRepository] and returns the repository result unchanged.
///
/// A `null` successful value indicates that settings have not yet been
/// initialized.
class GetSettingsUseCase {
  /// Creates a use case backed by [repository].
  const GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  /// Returns the currently persisted settings, or `null` when none exist.
  Future<Result<Settings?, BaseFailure>> call() {
    return _repository.get();
  }
}
