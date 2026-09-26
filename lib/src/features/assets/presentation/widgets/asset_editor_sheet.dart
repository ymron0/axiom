import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mutations/asset_mutations.dart';

/// Creates or edits one asset.
final class AssetEditorSheet extends ConsumerStatefulWidget {
  /// Creates an asset editor.
  const AssetEditorSheet({this.asset, super.key});

  final Asset? asset;

  bool get isEditing => asset != null;

  @override
  ConsumerState<AssetEditorSheet> createState() => _AssetEditorSheetState();
}

final class _AssetEditorSheetState extends ConsumerState<AssetEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _symbolController;
  late final TextEditingController _decimalPlacesController;

  late AssetEditorType _type;
  late bool _paymentEnabled;

  @override
  void initState() {
    super.initState();

    final asset = widget.asset;

    _type = asset == null ? AssetEditorType.currency : _typeOf(asset);

    _paymentEnabled = asset is CryptoAsset ? asset.paymentEnabled : false;

    _nameController = TextEditingController(text: asset?.name ?? '');
    _codeController = TextEditingController(text: asset?.code.value ?? '');
    _symbolController = TextEditingController(text: asset?.symbol ?? '');
    _decimalPlacesController = TextEditingController(
      text: asset?.decimalPlaces.toString() ?? '2',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _symbolController.dispose();
    _decimalPlacesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = widget.asset == null
        ? createManagedAssetMutation
        : updateManagedAssetMutation(widget.asset!.id);

    final mutationState = ref.watch(mutation);
    final pending = mutationState is MutationPending;
    final failure = resultMutationFailure(mutationState);

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
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEditing ? 'Edit asset' : 'New asset',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.medium),
                DropdownButtonFormField<AssetEditorType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Asset type'),
                  items: AssetEditorType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.isEditing || pending
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _type = value;

                            if (_type != AssetEditorType.crypto) {
                              _paymentEnabled = false;
                            }
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _nameController,
                  enabled: !pending,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an asset name.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _codeController,
                  enabled: !pending,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: 'CHF',
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';

                    if (code.isEmpty) {
                      return 'Enter an asset code.';
                    }

                    if (_type == AssetEditorType.currency &&
                        !RegExp(r'^[A-Za-z]{3}$').hasMatch(code)) {
                      return 'Currency codes must contain exactly 3 letters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _symbolController,
                  enabled: !pending,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Symbol',
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _decimalPlacesController,
                  enabled: !pending,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Decimal places',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');

                    if (parsed == null) {
                      return 'Enter a whole number.';
                    }

                    if (parsed < 0) {
                      return 'Decimal places cannot be negative.';
                    }

                    return null;
                  },
                ),
                if (_type == AssetEditorType.crypto) ...[
                  const SizedBox(height: AppSpacing.small),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment enabled'),
                    subtitle: const Text(
                      'Allow this crypto asset in payment transactions',
                    ),
                    value: _paymentEnabled,
                    onChanged: pending
                        ? null
                        : (value) {
                            setState(() {
                              _paymentEnabled = value;
                            });
                          },
                  ),
                ],
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
                      : Text(widget.isEditing ? 'Save asset' : 'Create asset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final data = AssetEditorData(
      type: _type,
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      symbol: _symbolController.text,
      decimalPlaces: int.parse(_decimalPlacesController.text.trim()),
      paymentEnabled: _paymentEnabled,
    );

    final asset = widget.asset;

    if (asset == null) {
      executeCreateManagedAsset(ref, data);
    } else {
      executeUpdateManagedAsset(ref, original: asset, data: data);
    }
  }
}

AssetEditorType _typeOf(Asset asset) {
  return switch (asset) {
    Currency() => AssetEditorType.currency,
    CryptoAsset() => AssetEditorType.crypto,
    StockAsset() => AssetEditorType.stock,
    CommodityAsset() => AssetEditorType.commodity,
  };
}

extension on AssetEditorType {
  String get label {
    return switch (this) {
      AssetEditorType.currency => 'Currency',
      AssetEditorType.crypto => 'Crypto',
      AssetEditorType.stock => 'Stock',
      AssetEditorType.commodity => 'Commodity',
    };
  }
}
