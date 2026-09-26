import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/features/categories/presentation/providers/categories_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/formatting/presentation_formatters.dart';
import '../../../../core/presentation/widgets/content/app_content.dart';
import '../../../../core/presentation/widgets/entity/entity_visual.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/budget_period.dart';
import '../../domain/enums/category_kind.dart';
import '../mutations/category_mutations.dart';

@RoutePage()
final class CategoryDetailsPage extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailsPage({
    @PathParam('categoryId') required this.categoryId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = _parseCategoryId(categoryId);

    if (id == null) {
      return const Scaffold(
        body: Center(child: Text('Invalid category identifier.')),
      );
    }

    final category = ref.watch(categoryDetailsProvider(id));
    final deleteState = ref.watch(deleteCategoryMutation(id));

    ref.listen(deleteCategoryMutation(id), (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        context.router.maybePop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category'),
        actions: [
          IconButton(
            tooltip: 'Edit category',
            onPressed: () {
              context.router.push(EditCategoryRoute(categoryId: id.value));
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<_CategoryDetailsAction>(
            onSelected: (action) {
              switch (action) {
                case _CategoryDetailsAction.delete:
                  _confirmDelete(context, ref, id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CategoryDetailsAction.delete,
                child: Text('Delete category'),
              ),
            ],
          ),
        ],
      ),
      body: AsyncResultView<Category, BaseFailure>(
        value: category,
        onRetry: () {
          ref.invalidate(categoryDetailsProvider(id));
        },
        builder: (context, value) {
          return _CategoryDetailsBody(category: value);
        },
      ),
      bottomNavigationBar: deleteState is MutationPending
          ? const LinearProgressIndicator()
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryId id,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete category?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'The category can only be deleted when no transaction '
                'still references it.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      await executeDeleteCategory(ref, id);
    }
  }
}

enum _CategoryDetailsAction { delete }

final class _CategoryDetailsBody extends StatelessWidget {
  final Category category;

  const _CategoryDetailsBody({required this.category});

  @override
  Widget build(BuildContext context) {
    final formatters = PresentationFormatters.of(context);

    return AppContent(
      child: ListView(
        children: [
          Row(
            children: [
              EntityVisual(
                icon: category.icon,
                color: category.color,
                size: 56,
                semanticLabel: '${category.name} category',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(switch (category.kind) {
                      CategoryKind.expense => 'Expense category',
                      CategoryKind.income => 'Income category',
                    }, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Budgets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (category.budgets.isEmpty)
            const Text('No budget history.')
          else
            ...category.budgets.map((budget) {
              final period = switch (budget.period) {
                BudgetPeriod.monthly => 'Monthly',
                BudgetPeriod.yearly => 'Yearly',
              };

              final dateRange = budget.effectiveUntil == null
                  ? 'From ${formatters.dates.calendarDate(budget.effectiveFrom)}'
                  : '${formatters.dates.calendarDate(budget.effectiveFrom)}'
                        ' – '
                        '${formatters.dates.calendarDate(budget.effectiveUntil!)}';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  formatters.numbers.decimal(
                    budget.limit.amount,
                    maximumFractionDigits: 2,
                  ),
                ),
                subtitle: Text('$period · $dateRange'),
              );
            }),
        ],
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
