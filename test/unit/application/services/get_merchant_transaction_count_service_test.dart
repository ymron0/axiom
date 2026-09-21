@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_merchant_transaction_count_service.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/query_transactions_use_case_mock.dart';

void main() {
  group('GetMerchantTransactionCountService', () {
    late MockQueryTransactionsUseCase queryTransactions;
    late GetMerchantTransactionCountService service;

    final merchantId = MerchantId.fromString('merchant-grocery');

    setUpAll(() {
      registerFallbackValue(TransactionQuery());
    });

    setUp(() {
      queryTransactions = MockQueryTransactionsUseCase();

      service = GetMerchantTransactionCountService(
        queryTransactions: queryTransactions,
      );
    });

    test('returns the number of transactions associated with the merchant '
        'during the period', () async {
      // Given
      final transactions = <Transaction>[
        transactionFixture(id: 'transaction-1'),
        transactionFixture(id: 'transaction-2'),
        transactionFixture(id: 'transaction-3'),
      ];

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>(transactions));

      final effectiveFrom = DateTime.utc(2026, 1, 1);
      final effectiveUntil = DateTime.utc(2026, 2, 1);

      // When
      final result = await service(
        merchantId,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.valueOrNull, 3);

      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.merchantIds, {merchantId});
      expect(query.effectiveFrom, effectiveFrom);
      expect(query.effectiveUntil, effectiveUntil);

      expect(query.kinds, isEmpty);
      expect(query.states, isEmpty);
      expect(query.accountIds, isEmpty);
      expect(query.tagIds, isEmpty);
    });

    test('returns zero when the merchant has no transactions', () async {
      // Given
      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      // When
      final result = await service(
        merchantId,
        effectiveFrom: DateTime.utc(2026, 1, 1),
        effectiveUntil: DateTime.utc(2026, 2, 1),
      );

      // Then
      expect(result.valueOrNull, 0);

      verify(() => queryTransactions(any())).called(1);
    });

    test('normalizes period boundaries to UTC', () async {
      // Given
      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      final effectiveFrom = DateTime.parse('2026-01-01T01:00:00+01:00');
      final effectiveUntil = DateTime.parse('2026-02-01T01:00:00+01:00');

      // When
      await service(
        merchantId,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.effectiveFrom, DateTime.utc(2026, 1, 1));
      expect(query.effectiveUntil, DateTime.utc(2026, 2, 1));
    });

    test('allows an empty period', () async {
      // Given
      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      final boundary = DateTime.utc(2026, 1, 1);

      // When
      final result = await service(
        merchantId,
        effectiveFrom: boundary,
        effectiveUntil: boundary,
      );

      // Then
      expect(result.valueOrNull, 0);

      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.effectiveFrom, boundary);
      expect(query.effectiveUntil, boundary);
    });

    test('rejects an invalid period before querying transactions', () async {
      // Given
      final effectiveFrom = DateTime.utc(2026, 2, 1);
      final effectiveUntil = DateTime.utc(2026, 1, 1);

      // When / Then
      expect(
        () => service(
          merchantId,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        ),
        throwsArgumentError,
      );

      verifyNever(() => queryTransactions(any()));
    });

    test('propagates transaction query failures unchanged', () async {
      // Given
      const failure = TransactionNotFoundFailure(
        message: 'Transaction query failed.',
      );

      when(() => queryTransactions(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(
        merchantId,
        effectiveFrom: DateTime.utc(2026, 1, 1),
        effectiveUntil: DateTime.utc(2026, 2, 1),
      );

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
