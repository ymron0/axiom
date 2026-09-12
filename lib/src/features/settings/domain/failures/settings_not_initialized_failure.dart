import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_not_initialized_failure.mapper.dart';

/// Indicates that application settings have not been initialized.
@MappableClass()
final class SettingsNotInitializedFailure
    extends Failure<SettingsNotInitializedFailure>
    with SettingsNotInitializedFailureMappable
    implements SettingsFailure {
  /// Creates a settings-not-initialized failure with optional details.
  const SettingsNotInitializedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.notInitialized';

  @override
  SettingsNotInitializedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
