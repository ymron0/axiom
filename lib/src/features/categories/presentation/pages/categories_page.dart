import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/widgets/content/app_content.dart';
import '../../../../core/presentation/widgets/entity/entity_visual.dart';
import '../../../../core/presentation/widgets/list/app_list_item.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_kind.dart';
import '../providers/categories_state.dart';
import '../state/categories_view_controller.dart';

@RoutePage()
final class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(visibleCategoriesProvider);
    final viewState = ref.watch(categoriesViewControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Manage tags',
            onPressed: () {
              context.router.push(const TagManagementRoute());
            },
            icon: const Icon(Icons.label_outline_rounded),
          ),
          PopupMenuButton<_CategoriesMenuAction>(
            tooltip: 'More category options',
            onSelected: (action) {
              switch (action) {
                case _CategoriesMenuAction.showDeleted:
                  ref
                      .read(categoriesViewControllerProvider.notifier)
                      .setIncludeDeleted(!viewState.includeDeleted);
                case _CategoriesMenuAction.clearFilters:
                  ref
                      .read(categoriesViewControllerProvider.notifier)
                      .clearFilters();
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _CategoriesMenuAction.showDeleted,
                checked: viewState.includeDeleted,
                child: const Text('Show deleted'),
              ),
              const PopupMenuItem(
                value: _CategoriesMenuAction.clearFilters,
                child: Text('Clear filters'),
              ),
            ],
          ),
        ],
      ),
      body: AsyncResultView<List<Category>, BaseFailure>(
        value: categories,
        isEmpty: (items) => items.isEmpty,
        emptyTitle: 'No categories',
        emptyMessage: 'Create a category to start organizing transactions.',
        onRetry: () {
          ref.invalidate(categoriesProvider);
        },
        builder: (context, items) {
          return AppContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBar(
                  hintText: 'Search categories',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (viewState.searchQuery.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          ref
                              .read(
                                categoriesViewControllerProvider.notifier,
                              )
                              .setSearchQuery('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (value) {
                    ref
                        .read(categoriesViewControllerProvider.notifier)
                        .setSearchQuery(value);
                  },
                ),
                const SizedBox(height: 12),
                _CategoryKindFilters(
                  selected: viewState.kind,
                  onChanged: (value) {
                    ref
                        .read(categoriesViewControllerProvider.notifier)
                        .setKind(value);
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _CategoriesList(categories: items),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.router.push(const CreateCategoryRoute());
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category'),
      ),
    );
  }
}

enum _CategoriesMenuAction {
  showDeleted,
  clearFilters,
}

final class _CategoryKindFilters extends StatelessWidget {
  final CategoryKind? selected;
  final ValueChanged<CategoryKind?> onChanged;

  const _CategoryKindFilters({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Category type filter',
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          FilterChip(
            label: const Text('Expense'),
            selected: selected == CategoryKind.expense,
            onSelected: (_) => onChanged(CategoryKind.expense),
          ),
          FilterChip(
            label: const Text('Income'),
            selected: selected == CategoryKind.income,
            onSelected: (_) => onChanged(CategoryKind.income),
          ),
        ],
      ),
    );
  }
}

final class _CategoriesList extends StatelessWidget {
  final List<Category> categories;

  const _CategoriesList({
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {
      for (final category in categories) category.id: category,
    };

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final parent = category.parentCategoryId == null
            ? null
            : byId[category.parentCategoryId];

        final subtitleParts = <String>[
          switch (category.kind) {
            CategoryKind.expense => 'Expense',
            CategoryKind.income => 'Income',
          },
          if (parent != null) 'Under ${parent.name}',
          if (category.isDeleted) 'Deleted',
        ];

        return Padding(
          padding: EdgeInsets.only(
            left: category.parentCategoryId == null ? 0 : 20,
          ),
          child: AppListItem(
            semanticLabel: '${category.name}, ${subtitleParts.join(', ')}',
            leading: EntityVisual(
              icon: category.icon,
              color: category.color,
              semanticLabel: '${category.name} category',
            ),
            title: Text(category.name),
            subtitle: Text(subtitleParts.join(' · ')),
            trailing: Icon(
              EntityIconResolver.resolve(category.icon),
              size: 0,
            ),
            enabled: !category.isDeleted,
            onTap: category.isDeleted
                ? null
                : () {
                    context.router.push(
                      CategoryDetailsRoute(
                        categoryId: category.id.value,
                      ),
                    );
                  },
          ),
        );
      },
    );
  }
}
