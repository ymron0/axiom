import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Creates and persists a new asset.
final class CreateAssetUseCase {
  /// Creates a use case with its repository and time source.
  const CreateAssetUseCase({
    required AssetRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final AssetRepository _repository;
  final Clock _clock;

  /// Creates and persists an asset from [command].
  ///
  /// Returns the created asset on success or an [AssetFailure].
  Future<Result<Asset, AssetFailure>> call(CreateAssetCommand command) async {
    final asset = Asset.create(
      name: command.name,
      code: command.code,
      symbol: command.symbol,
      remoteLogoUrl: command.remoteLogoUrl,
      bundledLogoAsset: command.bundledLogoAsset,
      decimalPlaces: command.decimalPlaces,
      clock: _clock,
    );
    final createResult = await _repository.create(asset);

    return createResult.when<Result<Asset, AssetFailure>>(
      success: (_) => Success(asset),
      failure: (failure) => failure,
    );
  }
}
