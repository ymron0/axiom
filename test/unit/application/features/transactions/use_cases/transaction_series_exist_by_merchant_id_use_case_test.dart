@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_merchant_id_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('TransactionSeriesExistByMerchantIdUseCase', () {
    late MockTransactionSeriesRepository repository;
    late TransactionSeriesExistByMerchantIdUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = TransactionSeriesExistByMerchantIdUseCase(
        repository: repository,
      );
    });

    test(
      'returns whether a transaction series references the merchant',
      () async {
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
      },
    );

    test('propagates repository failures', () async {
      // Given
      final merchantId = MerchantId.fromString('merchant-failure');
      const failure = TestTransactionSeriesFailure(message: 'lookup failed');

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
