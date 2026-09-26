import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
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
final class EditCategoryPage extends ConsumerStatefulWidget {
  final String categoryId;

  const EditCategoryPage({
    @PathParam('categoryId') required this.categoryId,
    super.key,
  });

  @override
  ConsumerState<EditCategoryPage> createState() => _EditCategoryPageState();
}

final class _EditCategoryPageState extends ConsumerState<EditCategoryPage> {
  CategoryFormState? _form;

  @override
  Widget build(BuildContext context) {
    final id = _parseCategoryId(widget.categoryId);

    if (id == null) {
      return const Scaffold(
        body: Center(child: Text('Invalid category identifier.')),
      );
    }

    final category = ref.watch(categoryDetailsProvider(id));
    final categories = ref.watch(categoriesProvider);
    final mutationState = ref.watch(updateCategoryMutation);
    final failure = resultMutationFailure(mutationState);

    ref.listen(updateCategoryMutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        context.router.maybePop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit category')),
      body: AsyncResultView<Category, BaseFailure>(
        value: category,
        onRetry: () {
          ref.invalidate(categoryDetailsProvider(id));
        },
        builder: (context, original) {
          final allCategories =
              categories.value?.valueOrNull ?? const <Category>[];

          _form ??= CategoryFormState.fromCategory(original);

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
                  value: _form!,
                  categories: allCategories,
                  editedCategoryId: original.id,
                  enabled: mutationState is! MutationPending,
                  submitLabel: 'Save changes',
                  onChanged: (value) {
                    setState(() {
                      _form = value;
                    });
                  },
                  onSubmit: () {
                    executeUpdateCategory(
                      ref,
                      original: original,
                      form: _form!,
                    );
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

CategoryId? _parseCategoryId(String value) {
  try {
    return CategoryId.fromString(value);
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}
