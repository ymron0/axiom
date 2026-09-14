@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/delete_merchant_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/di/delete_merchant_use_case_provider.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_merchant_id_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../mocks/delete_merchant_use_case_mock.dart';
import '../../../../mocks/transactions_exist_by_merchant_id_use_case_mock.dart';

void main() {
  group('deleteMerchantServiceProvider', () {
    test('uses the configured transaction check and merchant deletion', () async {
      // Given
      final transactionsExist = MockTransactionsExistByMerchantIdUseCase();
      final deleteMerchant = MockDeleteMerchantUseCase();
      final merchant = merchantFixture(
        id: 'provider-merchant',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => transactionsExist(merchant.id),
      ).thenAnswer((_) async => const Success(false));
      when(
        () => deleteMerchant(merchant.id),
      ).thenAnswer((_) async => Success<Merchant>(merchant));
      final container = ProviderContainer(
        overrides: [
          transactionsExistByMerchantIdUseCaseProvider.overrideWithValue(
            transactionsExist,
          ),
          deleteMerchantUseCaseProvider.overrideWithValue(deleteMerchant),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(deleteMerchantServiceProvider)(
        merchant.id,
      );

      // Then
      expect(result.valueOrNull, same(merchant));
      verify(() => transactionsExist(merchant.id)).called(1);
      verify(() => deleteMerchant(merchant.id)).called(1);
    });
  });
}
