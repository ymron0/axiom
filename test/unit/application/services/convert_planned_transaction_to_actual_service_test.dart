@Tags(['application'])
library;

import 'package:axiom/src/application/services/convert_planned_transaction_to_actual_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_actual_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/category_repository_mock.dart';
import '../../../mocks/jar_repository_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('ConvertPlannedTransactionToActualService', () {
    final now = DateTime.utc(2026, 9, 19, 8, 30);

    late MockTransactionRepository repository;
    late ConvertPlannedTransactionToActualService service;

    setUpAll(() {
      registerFallbackValue(transactionFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockTransactionRepository();

      final getTransactionById = GetTransactionByIdUseCase(repository);

      final allocationValidator = ValidateTransactionAllocationsService(
        getCategoryById: GetCategoryByIdUseCase(MockCategoryRepository()),
        getJarById: GetJarByIdUseCase(MockJarRepository()),
      );

      final tagValidator = ValidateTransactionTagsService(
        getTagsByIds: GetTagsByIdsUseCase(MockTagRepository()),
      );

      final updateService = UpdateTransactionService(
        getTransactionById: getTransactionById,
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAllocations: allocationValidator,
        validateTags: tagValidator,
      );

      service = ConvertPlannedTransactionToActualService(
        clock: FixedClock(now),
        getTransactionById: getTransactionById,
        updateTransaction: updateService,
      );
    });

    test('converts a planned transaction while preserving identity', () async {
      final planned = _plannedTransaction(id: 'planned');

      when(
        () => repository.getById(planned.id),
      ).thenAnswer((_) async => Success<Transaction?>(planned));

      when(
        () => repository.update(any()),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(id: planned.id);

      final actual = result.valueOrNull!;

      expect(actual.id, planned.id);
      expect(actual.state, TransactionState.actual);
      expect(actual.effectiveAt, now);
      expect(actual.createdAt, planned.createdAt);
      expect(actual.modifiedAt, now);
      expect(actual.entityVersion, planned.entityVersion);
      expect(actual.ledgerEntries, planned.ledgerEntries);
      expect(actual.splits, planned.splits);
      expect(actual.tagIds, planned.tagIds);

      final captured =
          verify(() => repository.update(captureAny())).captured.single
              as Transaction;

      expect(captured.id, planned.id);
      expect(captured.state, TransactionState.actual);
    });

    test('uses explicitly supplied effective time', () async {
      final planned = _plannedTransaction(id: 'historical');

      final effectiveAt = DateTime.utc(2026, 9, 15, 12);

      when(
        () => repository.getById(planned.id),
      ).thenAnswer((_) async => Success<Transaction?>(planned));

      when(
        () => repository.update(any()),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(id: planned.id, effectiveAt: effectiveAt);

      expect(result.valueOrNull!.effectiveAt, effectiveAt);

      expect(result.valueOrNull!.modifiedAt, now);
    });

    test('returns not-found when the transaction does not exist', () async {
      final planned = _plannedTransaction(id: 'missing');

      when(
        () => repository.getById(planned.id),
      ).thenAnswer((_) async => const Success<Transaction?>(null));

      final result = await service(id: planned.id);

      expect(result.failureOrNull, isA<TransactionNotFoundFailure>());

      verifyNever(() => repository.update(any()));
    });

    test('rejects a transaction that is already actual', () async {
      final actual = transactionFixture(id: 'already-actual');

      when(
        () => repository.getById(actual.id),
      ).thenAnswer((_) async => Success<Transaction?>(actual));

      final result = await service(id: actual.id);

      expect(result.failureOrNull, isA<TransactionAlreadyActualFailure>());

      verifyNever(() => repository.update(any()));
    });

    test('propagates lookup failures', () async {
      final planned = _plannedTransaction(id: 'lookup-failure');

      const failure = TransactionNotFoundFailure(message: 'read failed');

      when(
        () => repository.getById(planned.id),
      ).thenAnswer((_) async => failure);

      final result = await service(id: planned.id);

      expect(result.failureOrNull, same(failure));

      verifyNever(() => repository.update(any()));
    });

    test('propagates update failures', () async {
      final planned = _plannedTransaction(id: 'update-failure');

      const failure = TransactionNotFoundFailure(message: 'update failed');

      when(
        () => repository.getById(planned.id),
      ).thenAnswer((_) async => Success<Transaction?>(planned));

      when(() => repository.update(any())).thenAnswer((_) async => failure);

      final result = await service(id: planned.id);

      expect(result.failureOrNull, same(failure));
    });
  });
}

Transaction _plannedTransaction({required String id}) {
  final actual = transactionFixture(id: id);

  return Transaction(
    id: actual.id,
    kind: actual.kind,
    merchantId: actual.merchantId,
    effectiveAt: actual.effectiveAt,
    description: actual.description,
    note: actual.note,
    state: TransactionState.planned,
    tagIds: actual.tagIds,
    splits: actual.splits,
    ledgerEntries: actual.ledgerEntries,
    createdAt: actual.createdAt,
    modifiedAt: actual.modifiedAt,
    entityVersion: actual.entityVersion,
  );
}
