import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';

import 'transaction_fixtures.dart';

/// Creates a reusable transaction creation command for tests.
CreateTransactionCommand createTransactionCommandFixture({
  DateTime? effectiveAt,
}) {
  final transaction = transactionFixture(
    id: 'transaction-command-source',
    effectiveAt: effectiveAt,
  );

  return CreateTransactionCommand(
    kind: transaction.kind,
    merchantId: transaction.merchantId,
    effectiveAt: transaction.effectiveAt,
    description: transaction.description,
    note: transaction.note,
    state: transaction.state,
    splits: transaction.splits,
    ledgerEntries: transaction.ledgerEntries,
  );
}
