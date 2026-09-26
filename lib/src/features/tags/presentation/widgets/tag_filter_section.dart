import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/presentation/providers/tags_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



/// Reusable multi-select tag filter.
///
/// This widget has no dependency on categories, jars, transaction state, or
/// transaction repositories.
final class TagFilterSection extends ConsumerWidget {
  final Set<TagId> selectedIds;
  final ValueChanged<Set<TagId>> onChanged;

  const TagFilterSection({
    required this.selectedIds,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(activeTagsProvider);

    return AsyncResultView<List<Tag>, BaseFailure>(
      value: tags,
      onRetry: () {
        ref.invalidate(activeTagsProvider);
      },
      emptyBuilder: (context) {
        return const SizedBox.shrink();
      },
      builder: (context, items) {
        return Semantics(
          label: 'Filter transactions by tags',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () => onChanged(const {}),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in items)
                    FilterChip(
                      label: Text(tag.name),
                      selected: selectedIds.contains(tag.id),
                      onSelected: (selected) {
                        final next = Set<TagId>.of(selectedIds);

                        if (selected) {
                          next.add(tag.id);
                        } else {
                          next.remove(tag.id);
                        }

                        onChanged(Set.unmodifiable(next));
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
