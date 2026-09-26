import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/presentation/widgets/content/app_content.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../../domain/entities/category.dart';
import '../mutations/category_mutations.dart';
import '../providers/categories_state.dart';
import '../state/category_form_state.dart';
import '../widgets/category_form.dart';

@RoutePage()
final class CreateCategoryPage extends ConsumerStatefulWidget {
  const CreateCategoryPage({super.key});

  @override
  ConsumerState<CreateCategoryPage> createState() => _CreateCategoryPageState();
}

final class _CreateCategoryPageState extends ConsumerState<CreateCategoryPage> {
  CategoryFormState _form = CategoryFormState.create();

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final mutationState = ref.watch(createCategoryMutation);
    final failure = resultMutationFailure(mutationState);

    ref.listen(createCategoryMutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        final created = value.valueOrNull!;

        context.router.replace(
          CategoryDetailsRoute(categoryId: created.id.value),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New category')),
      body: AsyncResultView<List<Category>, BaseFailure>(
        value: categories,
        onRetry: () => ref.invalidate(categoriesProvider),
        builder: (context, items) {
          return AppContent(
            child: ListView(
              children: [
                if (failure != null) ...[
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(failure.message),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                CategoryForm(
                  value: _form,
                  categories: items,
                  enabled: mutationState is! MutationPending,
                  submitLabel: 'Create category',
                  onChanged: (value) {
                    setState(() {
                      _form = value;
                    });
                  },
                  onSubmit: () {
                    executeCreateCategory(ref, _form);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
