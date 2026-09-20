@Tags(['di'])
library;

import 'package:axiom/src/features/assets/application/use_cases/get_payment_assets_use_case.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/di/get_payment_assets_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  test('provides the payment-assets use case', () {
    final container = ProviderContainer(
      overrides: [
        assetRepositoryProvider.overrideWithValue(MockAssetRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(getPaymentAssetsUseCaseProvider),
      isA<GetPaymentAssetsUseCase>(),
    );
  });
}
