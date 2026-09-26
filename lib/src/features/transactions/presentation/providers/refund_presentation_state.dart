import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_offset_summary_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_offsets_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/result/result.dart';
import '../models/refund_presentation_data.dart';

part 'refund_presentation_state.g.dart';

/// Loads the gross/offset/net presentation for an original transaction.
@riverpod
Future<Result<RefundPresentationData, BaseFailure>> refundPresentation(
  Ref ref,
  TransactionId transactionId,
) async {
  final getSummary = ref.watch(getTransactionOffsetSummaryUseCaseProvider);
  final getOffsets = ref.watch(getTransactionOffsetsUseCaseProvider);
  final getAsset = ref.watch(getAssetByIdUseCaseProvider);

  final summaryResult = widenResult(await getSummary(transactionId));

  if (summaryResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final summary = summaryResult.valueOrNull!;

  final offsetsResult = widenResult(await getOffsets(transactionId));

  if (offsetsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final assetResult = widenResult(await getAsset(summary.assetId));

  if (assetResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    RefundPresentationData(
      summary: summary,
      offsets: offsetsResult.valueOrNull!,
      asset: assetResult.valueOrNull!,
    ),
  );
}
