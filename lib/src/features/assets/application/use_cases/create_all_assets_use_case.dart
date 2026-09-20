import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_all_assets_command.dart';
import 'package:axiom/src/features/assets/application/mappers/create_asset_command_mapper.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Atomically creates and persists multiple concrete asset types.
final class CreateAllAssetsUseCase {
  static const CreateAssetCommandMapper _mapper = CreateAssetCommandMapper();

  final AssetRepository _repository;

  final Clock _clock;
  /// Creates the batch creation use case.
  const CreateAllAssetsUseCase({
    required AssetRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Creates all assets represented by [command] and persists them atomically.
  Future<Result<List<Asset>, AssetFailure>> call(
    CreateAllAssetsCommand command,
  ) async {
    final assets = command.commands
        .map(
          (assetCommand) =>
              _mapper.toEntity(command: assetCommand, clock: _clock),
        )
        .toList(growable: false);

    final result = await _repository.createAll(assets);

    return result.when<Result<List<Asset>, AssetFailure>>(
      success: (_) => Success(List.unmodifiable(assets)),
      failure: (failure) => failure,
    );
  }
}
