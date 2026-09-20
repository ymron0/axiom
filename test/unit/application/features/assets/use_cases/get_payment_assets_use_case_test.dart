@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_payment_assets_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  late MockAssetRepository repository;
  late GetPaymentAssetsUseCase useCase;

  setUp(() {
    repository = MockAssetRepository();
    useCase = GetPaymentAssetsUseCase(repository);
  });

  test('returns only payment-enabled assets in an unmodifiable list', () async {
    final currency = currencyFixture(id: 'currency');
    final disabledCrypto = cryptoAssetFixture(id: 'crypto-disabled');
    final enabledCrypto = cryptoAssetFixture(
      id: 'crypto-enabled',
      paymentEnabled: true,
    );
    when(() => repository.getAll()).thenAnswer(
      (_) async =>
          Success<List<Asset>>([currency, disabledCrypto, enabledCrypto]),
    );

    final result = await useCase();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, [currency, enabledCrypto]);
    expect(() => result.valueOrNull!.add(currency), throwsUnsupportedError);
  });

  test('propagates repository failures', () async {
    const failure = AssetRepositoryFailure(message: 'read failed');
    when(() => repository.getAll()).thenAnswer((_) async => failure);

    final result = await useCase();

    expect(result.failureOrNull, same(failure));
  });
}
