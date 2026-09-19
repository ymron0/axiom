import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_offset_policy_provider.g.dart';

/// Provides the stateless domain policy governing transaction offsets.
@riverpod
TransactionOffsetPolicy transactionOffsetPolicy(Ref ref) {
  return const TransactionOffsetPolicy();
}
