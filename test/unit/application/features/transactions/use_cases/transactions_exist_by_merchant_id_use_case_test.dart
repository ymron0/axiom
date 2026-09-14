@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_merchant_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('TransactionsExistByMerchantIdUseCase', () {
    late MockTransactionRepository repository;
    late TransactionsExistByMerchantIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = TransactionsExistByMerchantIdUseCase(repository);
    });

    test('returns whether persisted transactions reference the merchant', () async {
      // Given
      final merchantId = MerchantId.fromString('merchant-in-use');
      when(
        () => repository.existsByMerchantId(merchantId),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await useCase(merchantId);

      // Then
      expect(result.valueOrNull, isTrue);
      verify(() => repository.existsByMerchantId(merchantId)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final merchantId = MerchantId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(
        () => repository.existsByMerchantId(merchantId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(merchantId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
