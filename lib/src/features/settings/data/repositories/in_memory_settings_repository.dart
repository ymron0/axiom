import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:fixtures/fixtures.dart';

/// Stores the application's settings in memory.
///
/// The repository is initialized from the single settings fixture. A
/// successful [update] replaces the initialized settings.
final class InMemorySettingsRepository implements SettingsRepository {
  Settings? _settings = Settings(
    valuationCurrencyId: AssetId.fromString(
      settingsFixtures.first.valuationCurrencyId,
    ),
  );

  @override
  Future<Result<Settings, BaseFailure>> create(Settings settings) async {
    if (_settings != null) {
      return const RecordAlreadyExistsFailure(
        message: 'Settings have already been initialized.',
      );
    }

    _settings = settings;
    return Success(settings);
  }

  @override
  Future<Result<Settings?, BaseFailure>> get() async {
    return Success(_settings);
  }

  @override
  Future<Result<Settings, BaseFailure>> update(Settings settings) async {
    if (_settings == null) {
      return const RecordNotFoundFailure(
        message: 'Settings have not been initialized.',
      );
    }

    _settings = settings;
    return Success(settings);
  }
}
