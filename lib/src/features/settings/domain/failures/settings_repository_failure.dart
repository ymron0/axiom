import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_repository_failure.mapper.dart';

/// Indicates that a settings repository operation could not complete.
@MappableClass()
final class SettingsRepositoryFailure extends Failure<SettingsRepositoryFailure>
    with SettingsRepositoryFailureMappable
    implements SettingsFailure {
  /// Creates a settings repository failure with optional details.
  const SettingsRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.repository';

  @override
  SettingsRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
