// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_offset_kind.mapper.dart';

/// Describes why one transaction offsets another transaction.
@MappableEnum()
enum TransactionOffsetKind {
  /// Money returned by the original merchant.
  refund,

  /// Money received from another party to cover part or all of an expense.
  reimbursement,

  /// Money returned as a reward or promotional credit after a purchase.
  cashback,
}
