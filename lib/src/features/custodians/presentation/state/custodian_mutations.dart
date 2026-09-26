import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/custodians/di/create_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/update_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/presentation/models/custodian_form_data.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks custodian creation.
final createCustodianMutation = Mutation<Result<Custodian, CustodianFailure>>(
  label: 'create-custodian',
);

/// Tracks custodian editing.
final updateCustodianMutation = Mutation<Result<void, CustodianFailure>>(
  label: 'update-custodian',
);

/// Creates a custodian.
Future<Result<Custodian, CustodianFailure>?> executeCreateCustodian(
  WidgetRef ref,
  CustodianFormData data,
) async {
  try {
    final result = await createCustodianMutation.run(ref, (transaction) {
      final useCase = transaction.get(createCustodianUseCaseProvider);

      return useCase(data.toCreateCommand());
    });

    if (result.isSuccess) {
      ref.invalidate(custodiansProvider);
      ref.invalidate(nextCustodianSortOrderProvider);

      // New custodians must become immediately available in account forms.
      ref.invalidate(accountFormOptionsProvider(null));
    }

    return result;
  } on Object {
    return null;
  }
}

/// Updates one custodian.
Future<Result<void, CustodianFailure>?> executeUpdateCustodian(
  WidgetRef ref, {
  required Custodian original,
  required CustodianFormData data,
}) async {
  try {
    final result = await updateCustodianMutation.run(ref, (transaction) {
      final clock = transaction.get(clockProvider);
      final useCase = transaction.get(updateCustodianUseCaseProvider);

      final updated = data.applyTo(original, modifiedAt: clock.nowUtc);

      return useCase(updated);
    });

    if (result.isSuccess) {
      ref.invalidate(custodiansProvider);
      ref.invalidate(custodianProvider(original.id));
      ref.invalidate(custodianValuationProvider(original.id));
      ref.invalidate(nextCustodianSortOrderProvider);

      // Account forms may render the custodian's display name.
      ref.invalidate(accountFormOptionsProvider(original.id));
    }

    return result;
  } on Object {
    return null;
  }
}
