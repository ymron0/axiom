import 'package:axiom/src/application/di/services/delete_merchant_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/di/archive_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/create_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/unarchive_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/update_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/merchant_management_state.dart';

final createManagedMerchantMutation =
    Mutation<Result<Merchant, BaseFailure>>(
      label: 'create-managed-merchant',
    );

final updateManagedMerchantMutation =
    Mutation<Result<Object?, BaseFailure>>(
      label: 'update-managed-merchant',
    );

final archiveManagedMerchantMutation =
    Mutation<Result<Object?, BaseFailure>>(
      label: 'archive-managed-merchant',
    );

final unarchiveManagedMerchantMutation =
    Mutation<Result<Object?, BaseFailure>>(
      label: 'unarchive-managed-merchant',
    );

final deleteManagedMerchantMutation =
    Mutation<Result<Object?, BaseFailure>>(
      label: 'delete-managed-merchant',
    );

Future<Result<Merchant, BaseFailure>> executeCreateManagedMerchant(
  WidgetRef ref,
  String name,
) {
  return createManagedMerchantMutation.run(ref, (transaction) async {
    final useCase = transaction.get(createMerchantUseCaseProvider);

    final result = widenResult(await useCase(name.trim()));

    if (result.isSuccess) {
      ref.invalidate(managedMerchantsProvider);
    }

    return result;
  });
}

Future<Result<Object?, BaseFailure>> executeUpdateManagedMerchant(
  WidgetRef ref, {
  required Merchant merchant,
  required String name,
}) {
  final mutation = updateManagedMerchantMutation(merchant.id);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(updateMerchantUseCaseProvider);
    final clock = transaction.get(clockProvider);

    final updated = merchant.copyWith(
      name: name.trim(),
      modifiedAt: clock.nowUtc,
      entityVersion: merchant.entityVersion + 1,
    );

    final result = await useCase(updated);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (_) => const Success<Object?>(null),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      ref.invalidate(managedMerchantsProvider);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeArchiveManagedMerchant(
  WidgetRef ref,
  MerchantId merchantId,
) {
  final mutation = archiveManagedMerchantMutation(merchantId);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(archiveMerchantUseCaseProvider);

    final result = await useCase(merchantId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (merchant) => Success<Object?>(merchant),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      ref.invalidate(managedMerchantsProvider);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>>
executeUnarchiveManagedMerchant(
  WidgetRef ref,
  MerchantId merchantId,
) {
  final mutation = unarchiveManagedMerchantMutation(merchantId);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(
      unarchiveMerchantUseCaseProvider,
    );

    final result = await useCase(merchantId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (merchant) => Success<Object?>(merchant),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      ref.invalidate(managedMerchantsProvider);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeDeleteManagedMerchant(
  WidgetRef ref,
  MerchantId merchantId,
) {
  final mutation = deleteManagedMerchantMutation(merchantId);

  return mutation.run(ref, (transaction) async {
    final service = transaction.get(deleteMerchantServiceProvider);

    final result = await service(merchantId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (merchant) => Success<Object?>(merchant),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      ref.invalidate(managedMerchantsProvider);
    }

    return widened;
  });
}