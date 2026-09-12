import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_persistence_failure.mapper.dart';

/// Indicates that settings persistence failed unexpectedly.
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
