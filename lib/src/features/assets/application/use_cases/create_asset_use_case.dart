import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/application/mappers/create_asset_command_mapper.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Creates and persists one concrete asset.
final class CreateAssetUseCase {
  static const CreateAssetCommandMapper _mapper = CreateAssetCommandMapper();

  final AssetRepository _repository;

  final Clock _clock;
  /// Creates a use case with its repository and canonical clock.
  const CreateAssetUseCase({
    required AssetRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Creates the concrete asset represented by [command] and persists it.
  ///
  /// The command subtype determines the resulting domain subtype.
  Future<Result<Asset, AssetFailure>> call(CreateAssetCommand command) async {
    final asset = _mapper.toEntity(command: command, clock: _clock);

    final result = await _repository.create(asset);

    return result.when<Result<Asset, AssetFailure>>(
      success: (_) => Success(asset),
      failure: (failure) => failure,
    );
  }
}
