import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/presentation/models/jar_form_data.dart';
import 'package:axiom/src/features/jars/presentation/state/jar_mutations.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edits an existing jar.
@RoutePage()
final class EditJarPage extends ConsumerWidget {
  /// Creates the page.
  const EditJarPage({@PathParam('jarId') required this.jarId, super.key});

  final String jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseJarId(jarId);

    if (parsedId == null) {
      return const _InvalidJarEditPage();
    }

    final value = ref.watch(jarProvider(parsedId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit jar')),
      body: AsyncResultView<Jar?, JarFailure>(
        value: value,
        isEmpty: (jar) => jar == null,
        emptyTitle: 'Jar not found',
        emptyMessage: 'This jar can no longer be edited.',
        onRetry: () {
          ref.invalidate(jarProvider(parsedId));
        },
        builder: (context, jar) {
          if (jar == null) {
            return const SizedBox.shrink();
          }

          return _LoadedEditJar(jar: jar);
        },
      ),
    );
  }
}

final class _LoadedEditJar extends ConsumerWidget {
  const _LoadedEditJar({required this.jar});

  final Jar jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(jarFormOptionsProvider);

    final mutationState = ref.watch(updateJarMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return AsyncResultView<JarFormOptions, BaseFailure>(
      value: options,
      onRetry: () {
        ref.invalidate(jarFormOptionsProvider);
      },
      builder: (context, loaded) {
        return SingleChildScrollView(
          child: AppContent(
            child: JarForm(
              initialValue: JarFormData.fromJar(
                jar,
                asOf: loaded.effectiveDate,
              ),
              valuationCurrency: loaded.valuationCurrency,
              effectiveDate: loaded.effectiveDate,
              submitLabel: 'Save changes',
              failure: failure,
              submitting: submitting,
              onSubmit: (data) async {
                final result = await executeUpdateJar(
                  ref,
                  original: jar,
                  data: data,
                  options: loaded,
                );

                if (!context.mounted || result == null || result.isFailure) {
                  return;
                }

                context.router.pop();
              },
            ),
          ),
        );
      },
    );
  }
}

final class _InvalidJarEditPage extends StatelessWidget {
  const _InvalidJarEditPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit jar')),
      body: const Center(child: Text('The jar identifier is invalid.')),
    );
  }
}

JarId? _parseJarId(String value) {
  try {
    return JarId.fromString(value);
  } on ArgumentError {
    return null;
  }
}
