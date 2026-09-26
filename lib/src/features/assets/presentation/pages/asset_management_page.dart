import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/asset_management_state.dart';
import '../widgets/asset_editor_sheet.dart';

/// Manages persisted reference assets.
@RoutePage()
final class AssetManagementPage extends ConsumerStatefulWidget {
  /// Creates the asset-management page.
  const AssetManagementPage({super.key});

  @override
  ConsumerState<AssetManagementPage> createState() =>
      _AssetManagementPageState();
}

final class _AssetManagementPageState
    extends ConsumerState<AssetManagementPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(managedAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: AsyncResultView<List<Asset>, AssetFailure>(
        value: value,
        onRetry: () {
          ref.invalidate(managedAssetsProvider);
        },
        builder: (context, assets) {
          final visible = assets
              .where((asset) {
                final query = _query.trim().toLowerCase();

                if (query.isEmpty) {
                  return true;
                }

                return asset.name.toLowerCase().contains(query) ||
                    asset.code.value.toLowerCase().contains(query) ||
                    (asset.symbol?.toLowerCase().contains(query) ?? false);
              })
              .toList(growable: false);

          return AppContent(
            child: Column(
              children: [
                SearchBar(
                  leading: const Icon(Symbols.search_rounded),
                  hintText: 'Search assets',
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('No matching assets'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            return _AssetRow(asset: visible[index]);
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
              return const AssetEditorSheet();
            },
          );
        },
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Asset'),
      ),
    );
  }
}

final class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      leading: Icon(_iconFor(asset)),
      title: Text('${asset.code.value} · ${asset.name}'),
      subtitle: Text(_subtitle(asset)),
      trailing: const Icon(Symbols.edit_rounded),
      semanticLabel: '${asset.code.value}, ${asset.name}, ${_typeLabel(asset)}',
      onTap: () {
        showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) {
            return AssetEditorSheet(asset: asset);
          },
        );
      },
    );
  }

  String _subtitle(Asset asset) {
    final payment = asset.paymentEnabled
        ? 'Payment enabled'
        : 'Not a payment asset';

    return '${_typeLabel(asset)} · '
        '${asset.decimalPlaces} decimals · $payment';
  }
}

String _typeLabel(Asset asset) {
  return switch (asset) {
    Currency() => 'Currency',
    CryptoAsset() => 'Crypto',
    StockAsset() => 'Stock',
    CommodityAsset() => 'Commodity',
  };
}

IconData _iconFor(Asset asset) {
  return switch (asset) {
    Currency() => Symbols.currency_exchange_rounded,
    CryptoAsset() => Symbols.currency_bitcoin_rounded,
    StockAsset() => Symbols.show_chart_rounded,
    CommodityAsset() => Symbols.diamond_rounded,
  };
}
