import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/create_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/update_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/presentation/models/account_form_data.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks creation of an account.
final createAccountMutation = Mutation<Result<Account, AccountFailure>>(
  label: 'create-account',
);

/// Tracks updates to an account.
final updateAccountMutation = Mutation<Result<void, AccountFailure>>(
  label: 'update-account',
);

/// Executes account creation.
///
/// Watched account and custodian-account projections update automatically from
/// persistence. Only non-reactive derived projections are invalidated.
Future<Result<Account, AccountFailure>?> executeCreateAccount(
  WidgetRef ref,
  AccountFormData data,
) async {
  try {
    final result = await createAccountMutation.run(ref, (transaction) {
      final useCase = transaction.get(createAccountUseCaseProvider);

      return useCase(data.toCreateCommand());
    });

    if (result.isSuccess) {
      ref.invalidate(accountFormOptionsProvider(null));
      ref.invalidate(custodianValuationProvider(data.custodianId));
    }

    return result;
  } on Object {
    return null;
  }
}

/// Executes account editing.
///
/// Watched account projections require no explicit invalidation.
Future<Result<void, AccountFailure>?> executeUpdateAccount(
  WidgetRef ref, {
  required Account original,
  required AccountFormData data,
}) async {
  try {
    final result = await updateAccountMutation.run(ref, (transaction) {
      final clock = transaction.get(clockProvider);
      final useCase = transaction.get(updateAccountUseCaseProvider);

      final updated = data.applyTo(original, modifiedAt: clock.nowUtc);

      return useCase(updated);
    });

    if (result.isSuccess) {
      ref.invalidate(accountValuationPresentationProvider(original.id));

      ref.invalidate(custodianValuationProvider(original.custodianId));
      ref.invalidate(custodianValuationProvider(data.custodianId));

      ref.invalidate(accountFormOptionsProvider(data.custodianId));
    }

    return result;
  } on Object {
    return null;
  }
}
