import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_all_assets_command.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Atomically creates and persists multiple assets.
final class CreateAllAssetsUseCase {
  /// Creates a use case with its repository and time source.
  const CreateAllAssetsUseCase({
    required AssetRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final AssetRepository _repository;
  final Clock _clock;

  /// Creates and persists every asset described by [command].
  ///
  /// Returns the created assets on success or an [AssetFailure].
  Future<Result<List<Asset>, AssetFailure>> call(
    CreateAllAssetsCommand command,
  ) async {
    final assets = command.commands
        .map(
          (asset) => Asset.create(
            name: asset.name,
            code: asset.code,
            symbol: asset.symbol,
            remoteLogoUrl: asset.remoteLogoUrl,
            bundledLogoAsset: asset.bundledLogoAsset,
            decimalPlaces: asset.decimalPlaces,
            clock: _clock,
          ),
        )
        .toList(growable: false);
    final createResult = await _repository.createAll(assets);

    return createResult.when<Result<List<Asset>, AssetFailure>>(
      success: (_) => Success(assets),
      failure: (failure) => failure,
    );
  }
}
