@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/di/services/value_asset_amounts_service_provider.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_rate_at_use_case_mock.dart';

void main() {
  group('valueAssetAmountsServiceProvider', () {
    test(
      'resolves the value asset amounts service and uses dependencies',
      () async {
        // Given
        final getRateAt = MockGetRateAtUseCase();
        final resolveConversionRate = ResolveConversionRateService(
          getRateAt: getRateAt,
          canonicalBridgeAssetId: AssetId.fromString('usd'),
          rateConversion: const RateConversionService(),
        );
        final container = ProviderContainer(
          overrides: [
            resolveConversionRateServiceProvider.overrideWithValue(
              resolveConversionRate,
            ),
          ],
        );
        addTearDown(container.dispose);

        // When
        final service = container.read(valueAssetAmountsServiceProvider);
        final targetAssetId = AssetId.fromString('usd');
        final amount = AssetAmount.incoming(
          assetId: targetAssetId,
          amount: Decimal.fromInt(100),
        );
        final result = await service(
          amounts: [amount],
          targetAssetId: targetAssetId,
          at: DateTime.utc(2026, 1, 1),
        );

        // Then
        expect(service, isA<ValueAssetAmountsService>());
        expect(result.valueOrNull, amount);
      },
    );
  });
}
