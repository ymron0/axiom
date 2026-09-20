import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_persistence_failure.mapper.dart';

/// Indicates that a settings persistence operation could not be completed.
///
/// This failure represents expected persistence-layer problems such as:
///
/// - database access failures;
/// - filesystem failures;
/// - malformed persisted settings data that cannot be reconstructed.
///
/// Low-level persistence exceptions must not escape through
/// [SettingsRepository]. The persistent repository translates those failures
/// into this feature-specific failure.
///
/// This failure does not represent repository semantics such as attempting to
/// create settings when they already exist or updating settings before they
/// have been initialized. Those conditions use their dedicated domain
/// failures.
@MappableClass()
final class SettingsPersistenceFailure
    extends Failure<SettingsPersistenceFailure>
    with SettingsPersistenceFailureMappable
    implements SettingsFailure {
  /// Creates a settings-persistence failure with optional details.
  const SettingsPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.persistence';

  @override
  SettingsPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
