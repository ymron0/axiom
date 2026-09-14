@Tags(['application'])
library;

import 'package:axiom/src/application/services/delete_merchant_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_in_use_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../mocks/delete_merchant_use_case_mock.dart';
import '../../../mocks/transactions_exist_by_merchant_id_use_case_mock.dart';

void main() {
  group('DeleteMerchantService', () {
    late MockTransactionsExistByMerchantIdUseCase transactionsExist;
    late MockDeleteMerchantUseCase deleteMerchant;
    late DeleteMerchantService service;

    setUp(() {
      transactionsExist = MockTransactionsExistByMerchantIdUseCase();
      deleteMerchant = MockDeleteMerchantUseCase();
      service = DeleteMerchantService(
        transactionsExist: transactionsExist,
        deleteMerchant: deleteMerchant,
      );
    });

    test('deletes a merchant with no associated transactions', () async {
      // Given
      final merchant = merchantFixture(
        id: 'unused-merchant',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => transactionsExist(merchant.id),
      ).thenAnswer((_) async => const Success(false));
      when(
        () => deleteMerchant(merchant.id),
      ).thenAnswer((_) async => Success<Merchant>(merchant));

      // When
      final result = await service(merchant.id);

      // Then
      expect(result.valueOrNull, same(merchant));
      verify(() => transactionsExist(merchant.id)).called(1);
      verify(() => deleteMerchant(merchant.id)).called(1);
    });

    test('does not delete a merchant with associated transactions', () async {
      // Given
      final merchant = merchantFixture(id: 'used-merchant');
      when(
        () => transactionsExist(merchant.id),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await service(merchant.id);

      // Then
      expect(result.failureOrNull, isA<MerchantInUseFailure>());
      expect(result.failureOrNull?.message, contains(merchant.id.value));
      verify(() => transactionsExist(merchant.id)).called(1);
      verifyNever(() => deleteMerchant(merchant.id));
    });

    test('propagates transaction lookup failures without deleting', () async {
      // Given
      final merchant = merchantFixture(id: 'lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(
        () => transactionsExist(merchant.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(merchant.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => deleteMerchant(merchant.id));
    });

    test('propagates merchant deletion failures', () async {
      // Given
      final merchant = merchantFixture(id: 'missing-merchant');
      const failure = MerchantNotFoundFailure(message: 'missing');
      when(
        () => transactionsExist(merchant.id),
      ).thenAnswer((_) async => const Success(false));
      when(() => deleteMerchant(merchant.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(merchant.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => deleteMerchant(merchant.id)).called(1);
    });
  });
}
