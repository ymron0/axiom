import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/di/create_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/update_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/asset_management_state.dart';

/// Asset type exposed by the asset editor.
enum AssetEditorType { currency, crypto, stock, commodity }

/// Normalized input produced by the asset editor.
final class AssetEditorData {
  /// Creates asset-editor input.
  const AssetEditorData({
    required this.type,
    required this.name,
    required this.code,
    required this.symbol,
    required this.decimalPlaces,
    required this.paymentEnabled,
  });

  final AssetEditorType type;
  final String name;
  final String code;
  final String? symbol;
  final int decimalPlaces;
  final bool paymentEnabled;
}

final createManagedAssetMutation = Mutation<Result<Asset, BaseFailure>>(
  label: 'create-managed-asset',
);

final updateManagedAssetMutation = Mutation<Result<Asset, BaseFailure>>(
  label: 'update-managed-asset',
);

/// Creates an asset from presentation input.
Future<Result<Asset, BaseFailure>> executeCreateManagedAsset(
  WidgetRef ref,
  AssetEditorData data,
) {
  return createManagedAssetMutation.run(ref, (transaction) async {
    final createAsset = transaction.get(createAssetUseCaseProvider);

    final code = AssetCode(data.code.trim());

    final command = switch (data.type) {
      AssetEditorType.currency => CreateCurrencyCommand(
        name: data.name.trim(),
        code: code,
        symbol: _normalizeOptional(data.symbol),
        decimalPlaces: data.decimalPlaces,
      ),
      AssetEditorType.crypto => CreateCryptoAssetCommand(
        name: data.name.trim(),
        code: code,
        symbol: _normalizeOptional(data.symbol),
        decimalPlaces: data.decimalPlaces,
        paymentEnabled: data.paymentEnabled,
      ),
      AssetEditorType.stock => CreateStockAssetCommand(
        name: data.name.trim(),
        code: code,
        symbol: _normalizeOptional(data.symbol),
        decimalPlaces: data.decimalPlaces,
      ),
      AssetEditorType.commodity => CreateCommodityAssetCommand(
        name: data.name.trim(),
        code: code,
        symbol: _normalizeOptional(data.symbol),
        decimalPlaces: data.decimalPlaces,
      ),
    };

    final result = widenResult(await createAsset(command));

    if (result.isSuccess) {
      ref.invalidate(managedAssetsProvider);
    }

    return result;
  });
}

/// Updates mutable asset metadata while preserving the concrete subtype.
Future<Result<Asset, BaseFailure>> executeUpdateManagedAsset(
  WidgetRef ref, {
  required Asset original,
  required AssetEditorData data,
}) {
  final mutation = updateManagedAssetMutation(original.id);

  return mutation.run(ref, (transaction) async {
    final updateAsset = transaction.get(updateAssetUseCaseProvider);
    final clock = transaction.get(clockProvider);

    final code = AssetCode(data.code.trim());
    final symbol = _normalizeOptional(data.symbol);
    final now = clock.nowUtc;

    final updated = switch (original) {
      Currency() => original.copyWith(
        name: data.name.trim(),
        code: code,
        symbol: symbol,
        decimalPlaces: data.decimalPlaces,
        modifiedAt: now,
        entityVersion: original.entityVersion + 1,
      ),
      CryptoAsset() => original.copyWith(
        name: data.name.trim(),
        code: code,
        symbol: symbol,
        decimalPlaces: data.decimalPlaces,
        paymentEnabled: data.paymentEnabled,
        modifiedAt: now,
        entityVersion: original.entityVersion + 1,
      ),
      StockAsset() => original.copyWith(
        name: data.name.trim(),
        code: code,
        symbol: symbol,
        decimalPlaces: data.decimalPlaces,
        modifiedAt: now,
        entityVersion: original.entityVersion + 1,
      ),
      CommodityAsset() => original.copyWith(
        name: data.name.trim(),
        code: code,
        symbol: symbol,
        decimalPlaces: data.decimalPlaces,
        modifiedAt: now,
        entityVersion: original.entityVersion + 1,
      ),
    };

    final result = widenResult(await updateAsset(updated));

    if (result.isSuccess) {
      ref.invalidate(managedAssetsProvider);
    }

    return result;
  });
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();

  return normalized == null || normalized.isEmpty ? null : normalized;
}
