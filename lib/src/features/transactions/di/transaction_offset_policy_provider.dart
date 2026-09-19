import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_offset_policy_provider.g.dart';

/// Provides the stateless domain policy governing transaction offsets.
///
/// The policy is application-independent domain logic and contains no mutable
/// state.
///
/// It is kept alive because the persistent transaction repository also has an
/// application lifetime and depends on this policy for atomic offset
/// validation.
@Riverpod(keepAlive: true)
TransactionOffsetPolicy transactionOffsetPolicy(Ref ref) {
  return const TransactionOffsetPolicy();
}
