import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';

/// Input required to atomically create and persist multiple transactions.
final class CreateAllTransactionsCommand {
  /// Creates an immutable batch of transaction creation commands.
  CreateAllTransactionsCommand({
    required List<CreateTransactionCommand> commands,
  }) : commands = List.unmodifiable(commands);

  /// The transaction creation commands in persistence order.
  final List<CreateTransactionCommand> commands;
}
