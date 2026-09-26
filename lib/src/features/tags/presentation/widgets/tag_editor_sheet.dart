import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../domain/entities/tag.dart';
import '../mutations/tag_mutations.dart';

final class TagEditorSheet extends ConsumerStatefulWidget {
  final Tag? tag;

  const TagEditorSheet({this.tag, super.key});

  bool get isEditing => tag != null;

  @override
  ConsumerState<TagEditorSheet> createState() => _TagEditorSheetState();
}

final class _TagEditorSheetState extends ConsumerState<TagEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.tag?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = widget.tag == null
        ? createTagMutation
        : updateTagMutation(widget.tag!.id);

    final mutationState = ref.watch(mutation);
    final failure = resultMutationFailure(mutationState);
    final pending = mutationState is MutationPending;

    ref.listen(mutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        Navigator.pop(context, true);
      }
    });

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isEditing ? 'Rename tag' : 'New tag',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            enabled: !pending,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: failure?.message,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: pending ? null : _submit,
            child: pending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    final tag = widget.tag;

    if (tag == null) {
      executeCreateTag(ref, name);
    } else {
      executeUpdateTag(ref, tag: tag, name: name);
    }
  }
}
