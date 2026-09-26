import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/presentation/widgets/content/app_content.dart';
import '../../../../core/presentation/widgets/list/app_list_item.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../../domain/entities/tag.dart';
import '../mutations/tag_mutations.dart';
import '../providers/tags_state.dart';
import '../state/tags_view_controller.dart';
import '../widgets/tag_editor_sheet.dart';

@RoutePage()
final class TagManagementPage extends ConsumerWidget {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(visibleTagsProvider);
    final viewState = ref.watch(tagsViewControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            tooltip: viewState.includeArchived
                ? 'Hide archived tags'
                : 'Show archived tags',
            onPressed: () {
              ref
                  .read(tagsViewControllerProvider.notifier)
                  .setIncludeArchived(!viewState.includeArchived);
            },
            icon: Icon(
              viewState.includeArchived
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      body: AsyncResultView<List<Tag>, BaseFailure>(
        value: tags,
        isEmpty: (items) => items.isEmpty,
        emptyTitle: 'No tags',
        emptyMessage: 'Create reusable tags for transactions.',
        onRetry: () => ref.invalidate(tagsProvider),
        builder: (context, items) {
          return AppContent(
            child: Column(
              children: [
                SearchBar(
                  hintText: 'Search tags',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) {
                    ref
                        .read(tagsViewControllerProvider.notifier)
                        .setSearchQuery(value);
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final tag = items[index];

                      return _TagListItem(tag: tag);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet<bool>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) {
              return const TagEditorSheet();
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tag'),
      ),
    );
  }
}

final class _TagListItem extends ConsumerWidget {
  final Tag tag;

  const _TagListItem({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveMutation = tag.isArchived
        ? unarchiveTagMutation(tag.id)
        : archiveTagMutation(tag.id);

    final deleteMutation = deleteTagMutation(tag.id);

    final archiveState = ref.watch(archiveMutation);
    final deleteState = ref.watch(deleteMutation);

    final pending =
        archiveState is MutationPending || deleteState is MutationPending;

    final failure =
        resultMutationFailure(archiveState) ??
        resultMutationFailure(deleteState);

    if (failure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      });
    }

    return AppListItem(
      leading: Icon(
        tag.isArchived ? Icons.label_off_outlined : Icons.label_outline_rounded,
      ),
      title: Text(tag.name),
      subtitle: tag.isArchived ? const Text('Archived') : null,
      enabled: !pending,
      trailing: PopupMenuButton<_TagAction>(
        enabled: !pending,
        onSelected: (action) {
          switch (action) {
            case _TagAction.rename:
              showModalBottomSheet<bool>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) {
                  return TagEditorSheet(tag: tag);
                },
              );

            case _TagAction.archive:
              executeArchiveTag(ref, tag.id);

            case _TagAction.unarchive:
              executeUnarchiveTag(ref, tag.id);

            case _TagAction.delete:
              _confirmDelete(context, ref);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: _TagAction.rename, child: Text('Rename')),
          if (tag.isArchived)
            const PopupMenuItem(
              value: _TagAction.unarchive,
              child: Text('Unarchive'),
            )
          else
            const PopupMenuItem(
              value: _TagAction.archive,
              child: Text('Archive'),
            ),
          const PopupMenuItem(value: _TagAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
                'Delete "${tag.name}"?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'The tag will be removed from transactions before it is '
                'deleted.',
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
      await executeDeleteTag(ref, tag.id);
    }
  }
}

enum _TagAction { rename, archive, unarchive, delete }
