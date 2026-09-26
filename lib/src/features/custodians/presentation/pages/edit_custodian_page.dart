import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/presentation/models/custodian_form_data.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodian_mutations.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:axiom/src/features/custodians/presentation/widgets/custodian_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edits an existing custodian.
@RoutePage()
final class EditCustodianPage extends ConsumerWidget {
  /// Creates the page.
  const EditCustodianPage({
    @PathParam('custodianId') required this.custodianId,
    super.key,
  });

  final String custodianId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseCustodianId(custodianId);

    if (parsedId == null) {
      return const _InvalidCustodianEditPage();
    }

    final value = ref.watch(custodianProvider(parsedId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit custodian')),
      body: AsyncResultView<Custodian?, CustodianFailure>(
        value: value,
        isEmpty: (custodian) => custodian == null,
        emptyTitle: 'Custodian not found',
        emptyMessage: 'This custodian can no longer be edited.',
        onRetry: () {
          ref.invalidate(custodianProvider(parsedId));
        },
        builder: (context, custodian) {
          if (custodian == null) {
            return const SizedBox.shrink();
          }

          return _LoadedEditCustodian(custodian: custodian);
        },
      ),
    );
  }
}

final class _LoadedEditCustodian extends ConsumerWidget {
  const _LoadedEditCustodian({required this.custodian});

  final Custodian custodian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutationState = ref.watch(updateCustodianMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return SingleChildScrollView(
      child: AppContent(
        child: CustodianForm(
          initialValue: CustodianFormData.fromCustodian(custodian),
          submitLabel: 'Save changes',
          failure: failure,
          submitting: submitting,
          onSubmit: (data) async {
            final result = await executeUpdateCustodian(
              ref,
              original: custodian,
              data: data,
            );

            if (!context.mounted || result == null || result.isFailure) {
              return;
            }

            context.router.pop();
          },
        ),
      ),
    );
  }
}

final class _InvalidCustodianEditPage extends StatelessWidget {
  const _InvalidCustodianEditPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit custodian')),
      body: const Center(child: Text('The custodian identifier is invalid.')),
    );
  }
}

CustodianId? _parseCustodianId(String value) {
  try {
    return CustodianId.fromString(value);
  } on ArgumentError {
    return null;
  }
}
