import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/di/get_archived_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'merchant_management_state.g.dart';

/// Loads active and archived merchants for management.
@riverpod
Future<Result<List<Merchant>, BaseFailure>> managedMerchants(Ref ref) async {
  final activeResult = await ref.watch(getMerchantsUseCaseProvider)();

  if (activeResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final archivedResult = await ref.watch(getArchivedMerchantsUseCaseProvider)();

  if (archivedResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final merchants =
      <Merchant>[...activeResult.valueOrNull!, ...archivedResult.valueOrNull!]
        ..sort((left, right) {
          final archiveOrder = left.isArchived == right.isArchived
              ? 0
              : left.isArchived
              ? 1
              : -1;

          if (archiveOrder != 0) {
            return archiveOrder;
          }

          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });

  return Success(List.unmodifiable(merchants));
}
