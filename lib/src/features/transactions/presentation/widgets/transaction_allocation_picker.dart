import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/widgets/entity/entity_visual.dart';
import '../../../../core/presentation/widgets/list/app_list_item.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../jars/domain/entities/jar.dart';
import '../models/transaction_allocation_selection.dart';
import '../providers/transaction_allocation_state.dart';

/// Selects the category and jar attached to one transaction split/allocation.
///
/// Amount editing remains owned by the transaction editor.
final class TransactionAllocationPicker extends ConsumerWidget {
  final TransactionAllocationSelection value;
  final bool enabled;
  final ValueChanged<TransactionAllocationSelection> onChanged;

  const TransactionAllocationPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allocationCategoriesProvider);
    final jars = ref.watch(allocationJarsProvider);

    final categoryItems = categories.value?.valueOrNull ?? const <Category>[];
    final jarItems = jars.value?.valueOrNull ?? const <Jar>[];

    final selectedCategory = _findCategory(categoryItems, value.categoryId);

    final selectedJar = _findJar(jarItems, value.jarId);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.category_outlined),
          title: const Text('Category'),
          subtitle: Text(selectedCategory?.name ?? 'Not selected'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.categoryId != null)
                IconButton(
                  tooltip: 'Clear category',
                  onPressed: enabled
                      ? () {
                          onChanged(value.copyWith(categoryId: null));
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          enabled: enabled,
          onTap: enabled
              ? () async {
                  final selected = await showModalBottomSheet<Category>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (context) {
                      return const _CategoryPickerSheet();
                    },
                  );

                  if (selected != null) {
                    onChanged(value.copyWith(categoryId: selected.id));
                  }
                }
              : null,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.savings_outlined),
          title: const Text('Jar'),
          subtitle: Text(selectedJar?.name ?? 'Not selected'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.jarId != null)
                IconButton(
                  tooltip: 'Clear jar',
                  onPressed: enabled
                      ? () {
                          onChanged(value.copyWith(jarId: null));
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          enabled: enabled,
          onTap: enabled
              ? () async {
                  final selected = await showModalBottomSheet<Jar>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (context) {
                      return const _JarPickerSheet();
                    },
                  );

                  if (selected != null) {
                    onChanged(value.copyWith(jarId: selected.id));
                  }
                }
              : null,
        ),
      ],
    );
  }
}

final class _CategoryPickerSheet extends ConsumerWidget {
  const _CategoryPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allocationCategoriesProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: AsyncResultView<List<Category>, BaseFailure>(
          value: categories,
          emptyTitle: 'No categories',
          onRetry: () {
            ref.invalidate(allocationCategoriesProvider);
          },
          builder: (context, items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Text(
                    'Select category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final category = items[index];

                      return AppListItem(
                        leading: EntityVisual(
                          icon: category.icon,
                          color: category.color,
                        ),
                        title: Text(category.name),
                        onTap: () {
                          Navigator.pop(context, category);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _JarPickerSheet extends ConsumerWidget {
  const _JarPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jars = ref.watch(allocationJarsProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: AsyncResultView<List<Jar>, BaseFailure>(
          value: jars,
          emptyTitle: 'No jars',
          onRetry: () {
            ref.invalidate(allocationJarsProvider);
          },
          builder: (context, items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Text(
                    'Select jar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final jar = items[index];

                      return AppListItem(
                        leading: EntityVisual(icon: jar.icon, color: jar.color),
                        title: Text(jar.name),
                        onTap: () {
                          Navigator.pop(context, jar);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Category? _findCategory(List<Category> categories, Object? id) {
  for (final category in categories) {
    if (category.id == id) {
      return category;
    }
  }

  return null;
}

Jar? _findJar(List<Jar> jars, Object? id) {
  for (final jar in jars) {
    if (jar.id == id) {
      return jar;
    }
  }

  return null;
}
