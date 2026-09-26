import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mutations/merchant_mutations.dart';

/// Creates or renames a merchant.
final class MerchantEditorSheet extends ConsumerStatefulWidget {
  const MerchantEditorSheet({this.merchant, super.key});

  final Merchant? merchant;

  bool get isEditing => merchant != null;

  @override
  ConsumerState<MerchantEditorSheet> createState() =>
      _MerchantEditorSheetState();
}

final class _MerchantEditorSheetState
    extends ConsumerState<MerchantEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.merchant?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = widget.merchant == null
        ? createManagedMerchantMutation
        : updateManagedMerchantMutation(widget.merchant!.id);

    final state = ref.watch(mutation);
    final pending = state is MutationPending;
    final failure = resultMutationFailure(state);

    ref.listen(mutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      }
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.medium,
          right: AppSpacing.medium,
          top: AppSpacing.xSmall,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.medium,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Edit merchant' : 'New merchant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _nameController,
                enabled: !pending,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a merchant name.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (failure != null) ...[
                const SizedBox(height: AppSpacing.medium),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Text(failure.message),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.large),
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
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final merchant = widget.merchant;
    final name = _nameController.text.trim();

    if (merchant == null) {
      executeCreateManagedMerchant(ref, name);
    } else {
      executeUpdateManagedMerchant(ref, merchant: merchant, name: name);
    }
  }
}
