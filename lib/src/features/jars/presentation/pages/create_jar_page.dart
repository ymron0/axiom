import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/presentation/models/jar_form_data.dart';
import 'package:axiom/src/features/jars/presentation/state/jar_mutations.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates a new jar.
@RoutePage()
final class CreateJarPage extends ConsumerWidget {
  /// Creates the page.
  const CreateJarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(jarFormOptionsProvider);

    final mutationState = ref.watch(createJarMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return Scaffold(
      appBar: AppBar(title: const Text('Create jar')),
      body: AsyncResultView<JarFormOptions, BaseFailure>(
        value: options,
        onRetry: () {
          ref.invalidate(jarFormOptionsProvider);
        },
        loadingSemanticLabel: 'Loading jar form',
        builder: (context, loaded) {
          final initial = JarFormData(
            name: '',
            description: null,
            kind: JarKind.savingsGoal,
            icon: EntityIcon.savings,
            color: EntityColor.blue,
            sortOrder: loaded.nextSortOrder,
            targetAmount: null,
            targetDate: null,
          );

          return SingleChildScrollView(
            child: AppContent(
              child: JarForm(
                initialValue: initial,
                valuationCurrency: loaded.valuationCurrency,
                effectiveDate: loaded.effectiveDate,
                submitLabel: 'Create jar',
                failure: failure,
                submitting: submitting,
                onSubmit: (data) async {
                  final result = await executeCreateJar(
                    ref,
                    data: data,
                    options: loaded,
                  );

                  if (!context.mounted || result == null || result.isFailure) {
                    return;
                  }

                  context.router.replace(
                    JarDetailsRoute(jarId: result.valueOrNull!.id.value),
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
