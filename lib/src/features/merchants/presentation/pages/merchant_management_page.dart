import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../mutations/merchant_mutations.dart';
import '../state/merchant_management_state.dart';
import '../widgets/merchant_editor_sheet.dart';

/// Manages merchant reference data.
@RoutePage()
final class MerchantManagementPage extends ConsumerStatefulWidget {
  const MerchantManagementPage({super.key});

  @override
  ConsumerState<MerchantManagementPage> createState() =>
      _MerchantManagementPageState();
}

final class _MerchantManagementPageState
    extends ConsumerState<MerchantManagementPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(managedMerchantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merchants')),
      body: AsyncResultView<List<Merchant>, BaseFailure>(
        value: value,
        onRetry: () {
          ref.invalidate(managedMerchantsProvider);
        },
        builder: (context, merchants) {
          final query = _query.trim().toLowerCase();

          final visible = merchants
              .where(
                (merchant) =>
                    query.isEmpty ||
                    merchant.name.toLowerCase().contains(query),
              )
              .toList(growable: false);

          return AppContent(
            child: Column(
              children: [
                SearchBar(
                  leading: const Icon(Symbols.search_rounded),
                  hintText: 'Search merchants',
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('No matching merchants'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            return _MerchantRow(merchant: visible[index]);
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
              return const MerchantEditorSheet();
            },
          );
        },
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Merchant'),
      ),
    );
  }
}

final class _MerchantRow extends ConsumerWidget {
  const _MerchantRow({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveMutation = merchant.isArchived
        ? unarchiveManagedMerchantMutation(merchant.id)
        : archiveManagedMerchantMutation(merchant.id);

    final deleteMutation = deleteManagedMerchantMutation(merchant.id);

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
      enabled: !pending,
      leading: Icon(
        merchant.isArchived
            ? Symbols.inventory_2_rounded
            : Symbols.storefront_rounded,
      ),
      title: Text(merchant.name),
      subtitle: merchant.isArchived
          ? const Text('Archived')
          : const Text('Active'),
      semanticLabel:
          '${merchant.name}, '
          '${merchant.isArchived ? 'archived' : 'active'} merchant',
      trailing: PopupMenuButton<_MerchantAction>(
        enabled: !pending,
        onSelected: (action) {
          switch (action) {
            case _MerchantAction.edit:
              showModalBottomSheet<bool>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) {
                  return MerchantEditorSheet(merchant: merchant);
                },
              );

            case _MerchantAction.archive:
              executeArchiveManagedMerchant(ref, merchant.id);

            case _MerchantAction.unarchive:
              executeUnarchiveManagedMerchant(ref, merchant.id);

            case _MerchantAction.delete:
              _confirmDelete(context, ref);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: _MerchantAction.edit, child: Text('Edit')),
          if (merchant.isArchived)
            const PopupMenuItem(
              value: _MerchantAction.unarchive,
              child: Text('Unarchive'),
            )
          else
            const PopupMenuItem(
              value: _MerchantAction.archive,
              child: Text('Archive'),
            ),
          const PopupMenuItem(
            value: _MerchantAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete "${merchant.name}"?'),
          content: const Text(
            'A merchant referenced by a transaction cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await executeDeleteManagedMerchant(ref, merchant.id);
    }
  }
}

enum _MerchantAction { edit, archive, unarchive, delete }
