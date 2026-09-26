import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/presentation/mutations/transaction_mutations.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full/partial refund, reimbursement or cashback flow.
final class TransactionRefundSheet extends ConsumerStatefulWidget {
  final Transaction transaction;
  final TransactionActivityData data;

  /// Creates a transaction-offset sheet.
  const TransactionRefundSheet({
    required this.transaction,
    required this.data,
    super.key,
  });

  @override
  ConsumerState<TransactionRefundSheet> createState() =>
      _TransactionRefundSheetState();
}

final class _TransactionRefundSheetState
    extends ConsumerState<TransactionRefundSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;

  TransactionOffsetKind _kind = TransactionOffsetKind.refund;
  late MerchantId _merchantId;
  late DateTime _effectiveAt;
  late Set<TagId> _tagIds;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final primary = widget.transaction.ledgerEntries.singleWhere(
      (entry) => entry.role == LedgerEntryRole.primary,
    );

    _amountController = TextEditingController(
      text: primary.transactionAmount.amount.toString(),
    );
    _descriptionController = TextEditingController();
    _noteController = TextEditingController();

    _merchantId = widget.transaction.merchantId;
    _effectiveAt = widget.data.now;
    _tagIds = {...widget.transaction.tagIds};
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(
      refundTransactionMutation(widget.transaction.id.value),
    );

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
                  'Refund transaction',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                DropdownButtonFormField<TransactionOffsetKind>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: TransactionOffsetKind.refund,
                      child: Text('Refund'),
                    ),
                    DropdownMenuItem(
                      value: TransactionOffsetKind.reimbursement,
                      child: Text('Reimbursement'),
                    ),
                    DropdownMenuItem(
                      value: TransactionOffsetKind.cashback,
                      child: Text('Cashback'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _kind = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: _validateAmount,
                ),
                const SizedBox(height: AppSpacing.small),
                _merchantField(),
                const SizedBox(height: AppSpacing.small),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Date & time'),
                  subtitle: Text(
                    PresentationFormatters.of(
                      context,
                    ).dates.dateTime(_effectiveAt),
                  ),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: AppSpacing.small),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline_rounded),
                  title: const Text('Tags'),
                  subtitle: Text(
                    _tagIds.isEmpty ? 'None' : '${_tagIds.length} selected',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickTags,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                FilledButton(
                  onPressed: mutation.isPending ? null : _submit,
                  child: mutation.isPending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create refund'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _merchantField() {
    final merchants =
        widget.data.source.merchants.where((merchant) {
          return merchant.archivedAt == null || merchant.id == _merchantId;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return DropdownButtonFormField<MerchantId>(
      key: ValueKey(_merchantId),
      initialValue: _merchantId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Merchant'),
      items: [
        DropdownMenuItem(value: MerchantId.self, child: Text('No merchant')),
        for (final merchant in merchants)
          DropdownMenuItem(
            value: merchant.id,
            child: Text(
              merchant.archivedAt == null
                  ? merchant.name
                  : '${merchant.name} (archived)',
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

  Future<void> _pickDate() async {
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
            final tags =
                widget.data.source.tags.where((tag) {
                  return tag.archivedAt == null || selected.contains(tag.id);
                }).toList()..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

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

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an amount.';
    }

    final result = PresentationFormatters.of(
      context,
    ).numbers.parseDecimal(value);

    if (result.isFailure) {
      return 'Enter a valid amount.';
    }

    if (result.valueOrNull! <= Decimal.zero) {
      return 'Amount must be greater than zero.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final parsed = PresentationFormatters.of(
      context,
    ).numbers.parseDecimal(_amountController.text);

    try {
      await runRefundTransactionMutation(
        ref,
        TransactionRefundRequest(
          original: widget.transaction,
          offsetKind: _kind,
          merchantId: _merchantId,
          effectiveAt: _effectiveAt,
          amount: parsed.valueOrNull!,
          description: _optionalText(_descriptionController.text),
          note: _optionalText(_noteController.text),
          tagIds: _tagIds.toList(growable: false),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final mapper = const PresentationFailureMapper();

      final failure = error is TransactionMutationFailure
          ? mapper.fromFailure(error.failure)
          : mapper.fromObject(error);

      setState(() => _errorMessage = failure.message);
    }
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
