import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_already_initialized_failure.mapper.dart';

/// Indicates that application settings have already been initialized.
@MappableClass()
final class SettingsAlreadyInitializedFailure
    extends Failure<SettingsAlreadyInitializedFailure>
    with SettingsAlreadyInitializedFailureMappable
    implements SettingsFailure {
  /// Creates a settings-already-initialized failure with optional details.
  const SettingsAlreadyInitializedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.alreadyInitialized';

  @override
  SettingsAlreadyInitializedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
