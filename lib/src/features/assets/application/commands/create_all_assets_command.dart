import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';

/// Input required to atomically create and persist multiple assets.
final class CreateAllAssetsCommand {
  /// Creates an immutable batch of asset creation commands.
  CreateAllAssetsCommand({required List<CreateAssetCommand> commands})
    : commands = List.unmodifiable(commands);

  /// The asset creation commands in persistence order.
  final List<CreateAssetCommand> commands;
}
