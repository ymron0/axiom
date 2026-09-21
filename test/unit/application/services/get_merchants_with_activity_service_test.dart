@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_merchants_with_activity_service.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_merchants_use_case_mock.dart';
import '../../../mocks/query_transactions_use_case_mock.dart';

void main() {
  group('GetMerchantsWithActivityService', () {
    late MockQueryTransactionsUseCase queryTransactions;
    late MockGetMerchantsUseCase getMerchants;
    late GetMerchantsWithActivityService service;

    final effectiveFrom = DateTime.utc(2026, 1, 1);
    final effectiveUntil = DateTime.utc(2026, 2, 1);

    setUpAll(() {
      registerFallbackValue(TransactionQuery());
    });

    setUp(() {
      queryTransactions = MockQueryTransactionsUseCase();
      getMerchants = MockGetMerchantsUseCase();

      service = GetMerchantsWithActivityService(
        queryTransactions: queryTransactions,
        getMerchants: getMerchants,
      );

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      when(
        () => getMerchants(),
      ).thenAnswer((_) async => const Success<List<Merchant>>([]));
    });

    test(
      'returns only merchants referenced by transactions in the period',
      () async {
        // Given
        final groceries = merchantFixture(id: 'groceries', name: 'Groceries');

        final fuel = merchantFixture(id: 'fuel', name: 'Fuel');

        final unused = merchantFixture(id: 'unused', name: 'Unused');

        when(() => queryTransactions(any())).thenAnswer(
          (_) async => Success<List<Transaction>>([
            _transaction(id: 'transaction-1', merchantId: groceries.id),
            _transaction(id: 'transaction-2', merchantId: fuel.id),
          ]),
        );

        when(() => getMerchants()).thenAnswer(
          (_) async => Success<List<Merchant>>([groceries, fuel, unused]),
        );

        // When
        final result = await service(
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, [groceries, fuel]);
      },
    );

    test('returns each merchant only once', () async {
      // Given
      final merchant = merchantFixture(id: 'merchant', name: 'Merchant');

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(id: 'transaction-1', merchantId: merchant.id),
          _transaction(id: 'transaction-2', merchantId: merchant.id),
          _transaction(id: 'transaction-3', merchantId: merchant.id),
        ]),
      );

      when(
        () => getMerchants(),
      ).thenAnswer((_) async => Success<List<Merchant>>([merchant]));

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.valueOrNull, [merchant]);
    });

    test('preserves merchant collection ordering', () async {
      // Given
      final first = merchantFixture(id: 'first', name: 'First');

      final second = merchantFixture(id: 'second', name: 'Second');

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(id: 'transaction-second', merchantId: second.id),
          _transaction(id: 'transaction-first', merchantId: first.id),
        ]),
      );

      when(
        () => getMerchants(),
      ).thenAnswer((_) async => Success<List<Merchant>>([first, second]));

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.valueOrNull, [first, second]);
    });

    test('includes archived merchants with historical activity', () async {
      // Given
      final archivedAt = DateTime.utc(2026, 3, 1);

      final archived = merchantFixture(
        id: 'archived',
        name: 'Archived Merchant',
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(
            id: 'historical-transaction',
            merchantId: archived.id,
            effectiveAt: DateTime.utc(2026, 1, 15),
          ),
        ]),
      );

      when(
        () => getMerchants(),
      ).thenAnswer((_) async => Success<List<Merchant>>([archived]));

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.valueOrNull, [archived]);
    });

    test('excludes MerchantId.self from merchant activity', () async {
      // Given
      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(id: 'self-transaction-1', merchantId: MerchantId.self),
          _transaction(id: 'self-transaction-2', merchantId: MerchantId.self),
        ]),
      );

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.valueOrNull, isEmpty);

      verifyNever(() => getMerchants());
    });

    test('returns empty list when there is no activity', () async {
      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);

      verifyNever(() => getMerchants());
    });

    test(
      'queries only actual transactions using the requested period',
      () async {
        // Given
        final localFrom = DateTime(2026, 1, 1, 2);

        final localUntil = DateTime(2026, 2, 1, 2);

        // When
        await service(effectiveFrom: localFrom, effectiveUntil: localUntil);

        // Then
        final query =
            verify(() => queryTransactions(captureAny())).captured.single
                as TransactionQuery;

        expect(query.states, {TransactionState.actual});

        expect(query.kinds, isEmpty);
        expect(query.merchantIds, isEmpty);
        expect(query.accountIds, isEmpty);
        expect(query.tagIds, isEmpty);

        expect(query.effectiveFrom, localFrom.toUtc());

        expect(query.effectiveUntil, localUntil.toUtc());
      },
    );

    test('allows an empty period', () async {
      // Given
      final instant = DateTime.utc(2026, 1, 15);

      // When
      final result = await service(
        effectiveFrom: instant,
        effectiveUntil: instant,
      );

      // Then
      expect(result.isSuccess, isTrue);

      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.effectiveFrom, instant);
      expect(query.effectiveUntil, instant);
    });

    test('rejects a period whose end precedes its start', () async {
      // Given
      final from = DateTime.utc(2026, 2, 1);
      final until = DateTime.utc(2026, 1, 1);

      // When / Then
      expect(
        () => service(effectiveFrom: from, effectiveUntil: until),
        throwsArgumentError,
      );

      verifyNever(() => queryTransactions(any()));
      verifyNever(() => getMerchants());
    });

    test('propagates transaction query failures', () async {
      // Given
      const failure = TransactionRepositoryFailure(
        message: 'Transaction query failed.',
      );

      when(() => queryTransactions(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => getMerchants());
    });

    test('propagates merchant lookup failures', () async {
      // Given
      final merchantId = MerchantId.fromString('merchant');

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(id: 'transaction', merchantId: merchantId),
        ]),
      );

      const failure = MerchantRepositoryFailure(
        message: 'Merchant lookup failed.',
      );

      when(() => getMerchants()).thenAnswer((_) async => failure);

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('returns merchant-not-found when transaction activity references '
        'an unresolved merchant', () async {
      // Given
      final missingMerchantId = MerchantId.fromString('missing');

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([
          _transaction(id: 'transaction', merchantId: missingMerchantId),
        ]),
      );

      when(
        () => getMerchants(),
      ).thenAnswer((_) async => const Success<List<Merchant>>([]));

      // When
      final result = await service(
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, isA<MerchantNotFoundFailure>());

      expect(result.failureOrNull!.message, contains(missingMerchantId.value));
    });
  });
}

Transaction _transaction({
  required String id,
  required MerchantId merchantId,
  DateTime? effectiveAt,
}) {
  return transactionFixture(
    id: id,
    effectiveAt: effectiveAt,
  ).copyWith(merchantId: merchantId);
}
