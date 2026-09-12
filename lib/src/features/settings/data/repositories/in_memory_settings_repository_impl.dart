import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:fixtures/fixtures.dart';

/// Stores the application's settings in memory.
///
/// The repository is initialized from the single settings fixture. A
/// successful [update] replaces the initialized settings.
final class InMemorySettingsRepositoryImpl implements SettingsRepository {
  Settings? _settings = Settings(
    valuationCurrencyId: AssetId.fromString(
      settingsFixtures.first.valuationCurrencyId,
    ),
  );

  @override
  Future<Result<Settings, SettingsFailure>> create(Settings settings) async {
    if (_settings != null) {
      return const SettingsAlreadyInitializedFailure(
        message: 'Settings have already been initialized.',
      );
    }

    _settings = settings;
    return Success(settings);
  }

  @override
  Future<Result<Settings?, SettingsFailure>> get() async {
    return Success(_settings);
  }

  @override
  Future<Result<Settings, SettingsFailure>> update(Settings settings) async {
    if (_settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    _settings = settings;
    return Success(settings);
  }
}
