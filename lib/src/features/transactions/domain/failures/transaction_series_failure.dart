// coverage:ignore-file

import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Base interface for expected transaction series failures in the Transactions
/// bounded context.
abstract interface class TransactionSeriesFailure
    implements TransactionFailure {}
