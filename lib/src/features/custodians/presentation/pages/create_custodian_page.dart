import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/presentation/models/custodian_form_data.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodian_mutations.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:axiom/src/features/custodians/presentation/widgets/custodian_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates a custodian.
@RoutePage()
final class CreateCustodianPage extends ConsumerWidget {
  /// Creates the page.
  const CreateCustodianPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortOrder = ref.watch(nextCustodianSortOrderProvider);

    final mutationState = ref.watch(createCustodianMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return Scaffold(
      appBar: AppBar(title: const Text('Create custodian')),
      body: AsyncResultView<int, CustodianFailure>(
        value: sortOrder,
        onRetry: () {
          ref.invalidate(nextCustodianSortOrderProvider);
        },
        builder: (context, nextSortOrder) {
          final initial = CustodianFormData(
            name: '',
            kind: CustodianKind.bank,
            logoSource: EntityLogoSource.remote,
            logoValue: null,
            icon: EntityIcon.accountBalance,
            color: EntityColor.blue,
            sortOrder: nextSortOrder,
          );

          return SingleChildScrollView(
            child: AppContent(
              child: CustodianForm(
                initialValue: initial,
                submitLabel: 'Create custodian',
                failure: failure,
                submitting: submitting,
                onSubmit: (data) async {
                  final result = await executeCreateCustodian(ref, data);

                  if (!context.mounted || result == null || result.isFailure) {
                    return;
                  }

                  final created = result.valueOrNull!;

                  context.router.replace(
                    CustodianDetailsRoute(custodianId: created.id.value),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
