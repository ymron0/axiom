import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset_summary.dart';

import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/transaction.dart';

/// Data needed to render an original transaction's offset/refund summary.
final class RefundPresentationData {
  final TransactionOffsetSummary summary;
  final List<Transaction> offsets;
  final Asset asset;

  const RefundPresentationData({
    required this.summary,
    required this.offsets,
    required this.asset,
  });
}
