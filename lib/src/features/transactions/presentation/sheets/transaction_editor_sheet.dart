import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
import 'package:axiom/src/features/transactions/presentation/formatting/transaction_display.dart';
import 'package:axiom/src/features/transactions/presentation/mutations/transaction_mutations.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _FeeMode { assetAmount, percentage }

/// Create/edit transaction modal sheet.
///
/// The normal editor can reconstruct the standard one/two-primary-entry shape,
/// one optional fee, and one category/jar allocation.
///
/// Existing transactions with a more complex financial structure remain
/// editable for metadata and tags, while their financial entries are preserved.
final class TransactionEditorSheet extends ConsumerStatefulWidget {
  final TransactionActivityData data;
  final Transaction? transaction;

  /// Creates a create/edit sheet.
  const TransactionEditorSheet({
    required this.data,
    this.transaction,
    super.key,
  });

  @override
  ConsumerState<TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

final class _TransactionEditorSheetState
    extends ConsumerState<TransactionEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _secondaryAmountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;
  late final TextEditingController _feeAmountController;
  late final TextEditingController _feePercentageController;

  late TransactionKind _kind;
  late TransactionState _state;
  late MerchantId _merchantId;
  late DateTime _effectiveAt;

  AccountId? _primaryAccountId;
  AccountId? _secondaryAccountId;
  AssetId? _primaryAssetId;

  AssetAmountDirection _balanceCorrectionDirection =
      AssetAmountDirection.incoming;

  CategoryId? _categoryId;
  JarId? _jarId;
  Set<TagId> _tagIds = {};

  bool _hasFee = false;
  _FeeMode _feeMode = _FeeMode.assetAmount;
  AccountId? _feeAccountId;
  AssetId? _feeAssetId;

  late bool _financialEditable;

  String? _errorMessage;

  bool get _editing => widget.transaction != null;

  bool get _twoLegged =>
      _kind == TransactionKind.transfer ||
      _kind == TransactionKind.buy ||
      _kind == TransactionKind.sell;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    _amountController = TextEditingController();
    _secondaryAmountController = TextEditingController();
    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _feeAmountController = TextEditingController();
    _feePercentageController = TextEditingController();

    _kind = transaction?.kind ?? TransactionKind.expense;
    _state = transaction?.state ?? TransactionState.actual;
    _merchantId = transaction?.merchantId ?? MerchantId.self;
    _tagIds = {...?transaction?.tagIds};

    _effectiveAt = transaction?.effectiveAt.toLocal() ?? _defaultEffectiveAt();

    _financialEditable =
        transaction == null || _canRepresentFinancials(transaction);

    if (transaction == null) {
      _initializeNewFinancials();
    } else {
      _initializeExistingFinancials(transaction);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _secondaryAmountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    _feeAmountController.dispose();
    _feePercentageController.dispose();
    super.dispose();
  }

  DateTime _defaultEffectiveAt() {
    final now = widget.data.now;
    final month = widget.data.source.monthStart;

    if (month.year == now.year && month.month == now.month) {
      return now;
    }

    return DateTime(month.year, month.month, 1, 12);
  }

  void _initializeNewFinancials() {
    final activeAccounts =
        widget.data.source.accounts
            .where((account) => account.archivedAt == null)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (activeAccounts.isEmpty) {
      return;
    }

    _primaryAccountId = activeAccounts.first.id;
    _primaryAssetId = activeAccounts.first.denominationAssetId;
    _feeAccountId = activeAccounts.first.id;
    _feeAssetId = activeAccounts.first.denominationAssetId;

    if (activeAccounts.length > 1) {
      _secondaryAccountId = activeAccounts[1].id;
    }

    _applyKindDefaults();
  }

  void _initializeExistingFinancials(Transaction transaction) {
    final primaryEntries = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList();

    if (_twoLegged) {
      final outgoing = primaryEntries.firstWhere(
        (entry) => entry.transactionAmount.isOutgoing,
      );

      final incoming = primaryEntries.firstWhere(
        (entry) => entry.transactionAmount.isIncoming,
      );

      _primaryAccountId = outgoing.accountId;
      _primaryAssetId = outgoing.transactionAmount.assetId;
      _amountController.text = outgoing.transactionAmount.amount.toString();

      _secondaryAccountId = incoming.accountId;
      _secondaryAmountController.text = incoming.transactionAmount.amount
          .toString();
    } else if (primaryEntries.isNotEmpty) {
      final primary = primaryEntries.single;

      _primaryAccountId = primary.accountId;
      _primaryAssetId = primary.transactionAmount.assetId;
      _amountController.text = primary.transactionAmount.amount.toString();
      _balanceCorrectionDirection = primary.transactionAmount.direction;
    }

    if (transaction.splits.length == 1) {
      final split = transaction.splits.single;
      _categoryId = split.categoryId;
      _jarId = split.jarId;
    }

    final fees = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.fee)
        .toList(growable: false);

    if (fees.length == 1) {
      final fee = fees.single;

      _hasFee = true;
      _feeAccountId = fee.accountId;

      if (fee.feeExpression is PercentageFeeExpression) {
        _feeMode = _FeeMode.percentage;
        _feePercentageController.text = fee.feePercentage.toString();
      } else {
        _feeMode = _FeeMode.assetAmount;
        _feeAssetId = fee.transactionAmount.assetId;
        _feeAmountController.text = fee.transactionAmount.amount.toString();
      }
    }
  }

  bool _canRepresentFinancials(Transaction transaction) {
    final primaryCount = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .length;

    final feeCount = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.fee)
        .length;

    final expectedPrimaryCount =
        transaction.kind == TransactionKind.transfer ||
            transaction.kind == TransactionKind.buy ||
            transaction.kind == TransactionKind.sell
        ? 2
        : 1;

    return primaryCount == expectedPrimaryCount &&
        feeCount <= 1 &&
        transaction.splits.length <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = _editing
        ? ref.watch(updateTransactionMutation(widget.transaction!.id.value))
        : ref.watch(createTransactionMutation);

    final pending = mutationState.isPending;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.medium,
          right: AppSpacing.medium,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.medium,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _editing ? 'Edit transaction' : 'New transaction',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                _kindField(),
                const SizedBox(height: AppSpacing.small),
                _merchantField(),
                const SizedBox(height: AppSpacing.small),
                _stateField(),
                const SizedBox(height: AppSpacing.small),
                _effectiveDateField(),
                const SizedBox(height: AppSpacing.large),
                if (_editing && !_financialEditable) ...[
                  _complexTransactionNotice(),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (!_editing || _financialEditable) ...[
                  Text(
                    'Financial entry',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  if (_twoLegged)
                    _twoLegFinancialFields()
                  else
                    _singleLegFinancialFields(),
                  if (_kind.supportsSplits) ...[
                    const SizedBox(height: AppSpacing.medium),
                    _allocationFields(),
                  ],
                  const SizedBox(height: AppSpacing.medium),
                  _feeFields(),
                  const SizedBox(height: AppSpacing.large),
                ],
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: AppSpacing.small),
                _tagsField(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: pending
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: FilledButton(
                        onPressed: pending ? null : _submit,
                        child: pending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_editing ? 'Save' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kindField() {
    return DropdownButtonFormField<TransactionKind>(
      key: ValueKey(_kind),
      initialValue: _kind,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Type'),
      items: [
        for (final kind in TransactionKind.values)
          DropdownMenuItem(
            value: kind,
            child: Text(transactionKindLabel(kind)),
          ),
      ],
      onChanged: _editing
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _kind = value;
                _applyKindDefaults();

                if (!_kind.supportsSplits) {
                  _categoryId = null;
                  _jarId = null;
                }
              });
            },
    );
  }

  Widget _merchantField() {
    final merchants = _availableMerchants();

    return DropdownButtonFormField<MerchantId>(
      key: ValueKey(_merchantId),
      initialValue: _merchantId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Merchant'),
      items: [
        DropdownMenuItem(
          value: MerchantId.self,
          child: Text('No merchant'),
        ),
        for (final merchant in merchants)
          DropdownMenuItem(
            value: merchant.id,
            child: Text(
              merchant.archivedAt == null
                  ? merchant.name
                  : '${merchant.name} (archived)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _merchantId = value);
        }
      },
    );
  }

  Widget _stateField() {
    return DropdownButtonFormField<TransactionState>(
      key: ValueKey(_state),
      initialValue: _state,
      decoration: const InputDecoration(labelText: 'State'),
      items: const [
        DropdownMenuItem(value: TransactionState.actual, child: Text('Actual')),
        DropdownMenuItem(
          value: TransactionState.planned,
          child: Text('Planned'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _state = value);
        }
      },
    );
  }

  Widget _effectiveDateField() {
    final enabled = !_editing || _financialEditable;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_rounded),
      title: const Text('Date & time'),
      subtitle: Text(
        PresentationFormatters.of(context).dates.dateTime(_effectiveAt),
      ),
      enabled: enabled,
      onTap: enabled ? _pickEffectiveAt : null,
    );
  }

  Widget _complexTransactionNotice() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: const Text(
        'This transaction contains a financial structure that the compact '
        'editor cannot safely reconstruct. Its financial entries and effective '
        'time will be preserved, while merchant, state, description, note and '
        'tags remain editable.',
      ),
    );
  }

  Widget _singleLegFinancialFields() {
    return Column(
      children: [
        _accountField(
          label: 'Account',
          value: _primaryAccountId,
          onChanged: (value) {
            setState(() {
              _primaryAccountId = value;

              final account = widget.data.source.accountsById[value];

              if (account != null) {
                _primaryAssetId = account.denominationAssetId;
                _feeAccountId ??= account.id;
                _feeAssetId ??= account.denominationAssetId;
              }
            });
          },
        ),
        const SizedBox(height: AppSpacing.small),
        _assetField(
          label: 'Transaction asset',
          value: _primaryAssetId,
          onChanged: (value) {
            setState(() => _primaryAssetId = value);
          },
        ),
        if (_kind == TransactionKind.balanceCorrection) ...[
          const SizedBox(height: AppSpacing.small),
          DropdownButtonFormField<AssetAmountDirection>(
            key: ValueKey(_balanceCorrectionDirection),
            initialValue: _balanceCorrectionDirection,
            decoration: const InputDecoration(labelText: 'Direction'),
            items: const [
              DropdownMenuItem(
                value: AssetAmountDirection.incoming,
                child: Text('Increase balance'),
              ),
              DropdownMenuItem(
                value: AssetAmountDirection.outgoing,
                child: Text('Decrease balance'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _balanceCorrectionDirection = value);
              }
            },
          ),
        ],
        const SizedBox(height: AppSpacing.small),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
          validator: _validatePositiveAmount,
        ),
      ],
    );
  }

  Widget _twoLegFinancialFields() {
    final firstLabel = switch (_kind) {
      TransactionKind.buy => 'Settlement account',
      TransactionKind.sell => 'Asset account',
      _ => 'From account',
    };

    final secondLabel = switch (_kind) {
      TransactionKind.buy => 'Asset account',
      TransactionKind.sell => 'Settlement account',
      _ => 'To account',
    };

    return Column(
      children: [
        _accountField(
          label: firstLabel,
          value: _primaryAccountId,
          onChanged: (value) {
            setState(() {
              _primaryAccountId = value;
              _feeAccountId ??= value;
            });
          },
        ),
        const SizedBox(height: AppSpacing.small),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Outgoing amount',
            suffixText: _accountAssetCode(_primaryAccountId),
          ),
          validator: _validatePositiveAmount,
        ),
        const SizedBox(height: AppSpacing.small),
        _accountField(
          label: secondLabel,
          value: _secondaryAccountId,
          onChanged: (value) {
            setState(() => _secondaryAccountId = value);
          },
        ),
        const SizedBox(height: AppSpacing.small),
        TextFormField(
          controller: _secondaryAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Incoming amount',
            suffixText: _accountAssetCode(_secondaryAccountId),
          ),
          validator: _validatePositiveAmount,
        ),
      ],
    );
  }

  Widget _allocationFields() {
    return Column(
      children: [
        DropdownButtonFormField<CategoryId>(
          key: ValueKey(_categoryId),
          initialValue: _categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final category in _availableCategories())
              DropdownMenuItem(
                value: category.id,
                enabled:
                    category.archivedAt == null || category.id == _categoryId,
                child: Text(
                  category.archivedAt == null
                      ? category.name
                      : '${category.name} (archived)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: AppSpacing.small),
        DropdownButtonFormField<JarId>(
          key: ValueKey(_jarId),
          initialValue: _jarId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Jar'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final jar in _availableJars())
              DropdownMenuItem(
                value: jar.id,
                enabled: jar.archivedAt == null || jar.id == _jarId,
                child: Text(
                  jar.archivedAt == null ? jar.name : '${jar.name} (archived)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _jarId = value),
        ),
      ],
    );
  }

  Widget _feeFields() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasFee,
          title: const Text('Fee'),
          subtitle: const Text('Attach a transaction fee'),
          onChanged: (value) => setState(() => _hasFee = value),
        ),
        if (_hasFee) ...[
          const SizedBox(height: AppSpacing.xSmall),
          DropdownButtonFormField<_FeeMode>(
            key: ValueKey(_feeMode),
            initialValue: _feeMode,
            decoration: const InputDecoration(labelText: 'Fee type'),
            items: const [
              DropdownMenuItem(
                value: _FeeMode.assetAmount,
                child: Text('Asset amount'),
              ),
              DropdownMenuItem(
                value: _FeeMode.percentage,
                child: Text('Percentage'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _feeMode = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.small),
          _accountField(
            label: 'Fee account',
            value: _feeAccountId,
            onChanged: (value) {
              setState(() => _feeAccountId = value);
            },
          ),
          const SizedBox(height: AppSpacing.small),
          if (_feeMode == _FeeMode.percentage)
            TextFormField(
              controller: _feePercentageController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fee percentage',
                suffixText: '%',
              ),
              validator: _validatePositiveAmount,
            )
          else ...[
            _assetField(
              label: 'Fee asset',
              value: _feeAssetId,
              paymentOnly: false,
              onChanged: (value) {
                setState(() => _feeAssetId = value);
              },
            ),
            const SizedBox(height: AppSpacing.small),
            TextFormField(
              controller: _feeAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Fee amount'),
              validator: _validatePositiveAmount,
            ),
          ],
        ],
      ],
    );
  }

  Widget _tagsField() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.label_outline_rounded),
      title: const Text('Tags'),
      subtitle: Text(_tagIds.isEmpty ? 'None' : '${_tagIds.length} selected'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _pickTags,
    );
  }

  Widget _accountField({
    required String label,
    required AccountId? value,
    required ValueChanged<AccountId> onChanged,
  }) {
    final accounts = _availableAccounts(additionallyInclude: value);

    return DropdownButtonFormField<AccountId>(
      key: ValueKey('$label-${value?.value}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null ? 'Select an account.' : null,
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            enabled: account.archivedAt == null || account.id == value,
            child: Text(
              account.archivedAt == null
                  ? account.name
                  : '${account.name} (archived)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  Widget _assetField({
    required String label,
    required AssetId? value,
    required ValueChanged<AssetId> onChanged,
    bool? paymentOnly,
  }) {
    final restrictToPayment =
        paymentOnly ??
        (_kind == TransactionKind.expense || _kind == TransactionKind.income);

    final assets = widget.data.source.assets.where((asset) {
      return !restrictToPayment || asset.paymentEnabled || asset.id == value;
    }).toList();

    return DropdownButtonFormField<AssetId>(
      key: ValueKey('$label-${value?.value}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null ? 'Select an asset.' : null,
      items: [
        for (final asset in assets)
          DropdownMenuItem(
            value: asset.id,
            child: Text(
              '${asset.code.value} — ${asset.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  Future<void> _pickEffectiveAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_effectiveAt),
    );

    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTags() async {
    final selected = {..._tagIds};

    final result = await showModalBottomSheet<Set<TagId>>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final tags = _availableTags(selected);

            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tags',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(selected);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final tag in tags)
                          CheckboxListTile(
                            value: selected.contains(tag.id),
                            enabled:
                                tag.archivedAt == null ||
                                selected.contains(tag.id),
                            title: Text(
                              tag.archivedAt == null
                                  ? tag.name
                                  : '${tag.name} (archived)',
                            ),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked ?? false) {
                                  selected.add(tag.id);
                                } else {
                                  selected.remove(tag.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _tagIds = result);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_twoLegged && _primaryAccountId == _secondaryAccountId) {
      setState(() {
        _errorMessage = 'The two sides must use different accounts.';
      });
      return;
    }

    setState(() => _errorMessage = null);

    try {
      final financial = !_editing || _financialEditable
          ? _buildFinancialRequest()
          : null;

      if (_editing) {
        final original = widget.transaction!;

        await runUpdateTransactionMutation(
          ref,
          TransactionUpdateRequest(
            original: original,
            financial: financial,
            merchantId: _merchantId,
            effectiveAt: _financialEditable
                ? _effectiveAt
                : original.effectiveAt,
            description: _optionalText(_descriptionController.text),
            note: _optionalText(_noteController.text),
            state: _state,
            tagIds: _tagIds.toList(growable: false),
          ),
        );
      } else {
        await runCreateTransactionMutation(
          ref,
          TransactionCreateRequest(
            financial: financial!,
            merchantId: _merchantId,
            effectiveAt: _effectiveAt,
            description: _optionalText(_descriptionController.text),
            note: _optionalText(_noteController.text),
            state: _state,
            tagIds: _tagIds.toList(growable: false),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final mapper = const PresentationFailureMapper();

      final presentationFailure = error is TransactionMutationFailure
          ? mapper.fromFailure(error.failure)
          : mapper.fromObject(error);

      setState(() {
        _errorMessage = presentationFailure.message;
      });
    }
  }

  TransactionFinancialRequest _buildFinancialRequest() {
    final entries = <TransactionEntryRequest>[];

    if (_twoLegged) {
      final sourceAccount = widget.data.source.accountsById[_primaryAccountId]!;
      final targetAccount =
          widget.data.source.accountsById[_secondaryAccountId]!;

      entries.add(
        TransactionEntryRequest(
          accountId: sourceAccount.id,
          assetId: sourceAccount.denominationAssetId,
          amount: _parse(_amountController),
          direction: AssetAmountDirection.outgoing,
        ),
      );

      entries.add(
        TransactionEntryRequest(
          accountId: targetAccount.id,
          assetId: targetAccount.denominationAssetId,
          amount: _parse(_secondaryAmountController),
          direction: AssetAmountDirection.incoming,
        ),
      );
    } else {
      final direction = switch (_kind) {
        TransactionKind.expense => AssetAmountDirection.outgoing,
        TransactionKind.income ||
        TransactionKind.dividend ||
        TransactionKind.reward => AssetAmountDirection.incoming,
        TransactionKind.balanceCorrection => _balanceCorrectionDirection,
        _ => throw StateError('Expected a single-leg transaction.'),
      };

      entries.add(
        TransactionEntryRequest(
          accountId: _primaryAccountId!,
          assetId: _primaryAssetId!,
          amount: _parse(_amountController),
          direction: direction,
        ),
      );
    }

    TransactionFeeRequest? fee;

    if (_hasFee) {
      if (_feeMode == _FeeMode.percentage) {
        fee = TransactionFeeRequest.percentage(
          accountId: _feeAccountId!,
          percentage: _parse(_feePercentageController),
        );
      } else {
        fee = TransactionFeeRequest.assetAmount(
          accountId: _feeAccountId!,
          assetId: _feeAssetId!,
          amount: _parse(_feeAmountController),
        );
      }
    }

    return TransactionFinancialRequest(
      kind: _kind,
      entries: entries,
      categoryId: _kind.supportsSplits ? _categoryId : null,
      jarId: _kind.supportsSplits ? _jarId : null,
      fee: fee,
    );
  }

  void _applyKindDefaults() {
    if (_kind == TransactionKind.balanceCorrection) {
      _balanceCorrectionDirection = AssetAmountDirection.incoming;
    }

    if (!_kind.supportsSplits) {
      _categoryId = null;
      _jarId = null;
    }

    if (_kind == TransactionKind.transfer ||
        _kind == TransactionKind.balanceCorrection) {
      _merchantId = MerchantId.self;
    }

    final selectedAsset = _primaryAssetId;

    if ((_kind == TransactionKind.expense || _kind == TransactionKind.income) &&
        selectedAsset != null) {
      final asset = widget.data.source.assetsById[selectedAsset];

      if (asset != null && !asset.paymentEnabled) {
        final account = widget.data.source.accountsById[_primaryAccountId];

        final accountAsset = account == null
            ? null
            : widget.data.source.assetsById[account.denominationAssetId];

        if (accountAsset?.paymentEnabled ?? false) {
          _primaryAssetId = accountAsset!.id;
        } else {
          final paymentAssets = widget.data.source.assets
              .where((candidate) => candidate.paymentEnabled)
              .toList(growable: false);

          _primaryAssetId = paymentAssets.isEmpty
              ? null
              : paymentAssets.first.id;
        }
      }
    }
  }

  String? _validatePositiveAmount(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Enter an amount.';
    }

    final parsed = PresentationFormatters.of(
      context,
    ).numbers.parseDecimal(text);

    if (parsed.isFailure) {
      return 'Enter a valid amount.';
    }

    if (parsed.valueOrNull! <= Decimal.zero) {
      return 'Amount must be greater than zero.';
    }

    return null;
  }

  Decimal _parse(TextEditingController controller) {
    final result = PresentationFormatters.of(
      context,
    ).numbers.parseDecimal(controller.text);

    if (result.isFailure) {
      throw StateError('Form validation accepted an invalid number.');
    }

    return result.valueOrNull!;
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _accountAssetCode(AccountId? accountId) {
    if (accountId == null) {
      return null;
    }

    final account = widget.data.source.accountsById[accountId];
    final asset = account == null
        ? null
        : widget.data.source.assetsById[account.denominationAssetId];

    return asset?.code.value;
  }

  List<Account> _availableAccounts({AccountId? additionallyInclude}) {
    final selectedIds = {
      _primaryAccountId,
      _secondaryAccountId,
      _feeAccountId,
      additionallyInclude,
    };

    final result = widget.data.source.accounts.where((account) {
      return account.archivedAt == null || selectedIds.contains(account.id);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return result;
  }

  List<Merchant> _availableMerchants() {
    final result =
        widget.data.source.merchants.where((merchant) {
          return merchant.archivedAt == null || merchant.id == _merchantId;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return result;
  }

  List<Category> _availableCategories() {
    final result = widget.data.source.categories.where((category) {
      return category.archivedAt == null || category.id == _categoryId;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return result;
  }

  List<Jar> _availableJars() {
    final result = widget.data.source.jars.where((jar) {
      return jar.archivedAt == null || jar.id == _jarId;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return result;
  }

  List<Tag> _availableTags(Set<TagId> selected) {
    final result =
        widget.data.source.tags.where((tag) {
          return tag.archivedAt == null || selected.contains(tag.id);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return result;
  }
}
