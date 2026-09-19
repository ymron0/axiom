@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offset_summary_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offsets_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_offset_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(TransactionId.fromString('fallback-transaction'));
  });

  group('GetTransactionOffsetSummaryUseCase', () {
    late MockTransactionRepository repository;
    late GetTransactionOffsetSummaryUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();

      useCase = GetTransactionOffsetSummaryUseCase(
        getTransactionById: GetTransactionByIdUseCase(repository),
        getTransactionOffsets: GetTransactionOffsetsUseCase(
          repository: repository,
        ),
        offsetPolicy: const TransactionOffsetPolicy(),
      );
    });

    test('derives refund reimbursement cashback and net amounts', () async {
      final original = offsetOriginalTransactionFixture();

      final refund = offsetTransactionFixture(
        id: 'refund',
        amount: Decimal.fromInt(20),
        offsetKind: TransactionOffsetKind.refund,
      );

      final reimbursement = offsetTransactionFixture(
        id: 'reimbursement',
        amount: Decimal.fromInt(50),
        offsetKind: TransactionOffsetKind.reimbursement,
      );

      final cashback = offsetTransactionFixture(
        id: 'cashback',
        amount: Decimal.fromInt(5),
        offsetKind: TransactionOffsetKind.cashback,
      );

      when(
        () => repository.getById(original.id),
      ).thenAnswer((_) async => Success<Transaction?>(original));

      when(() => repository.getOffsetsForTransaction(original.id)).thenAnswer(
        (_) async =>
            Success<List<Transaction>>([refund, reimbursement, cashback]),
      );

      final result = await useCase(original.id);

      final summary = result.valueOrNull!;

      expect(summary.grossAmount, Decimal.fromInt(100));
      expect(summary.refundAmount, Decimal.fromInt(20));
      expect(summary.reimbursementAmount, Decimal.fromInt(50));
      expect(summary.cashbackAmount, Decimal.fromInt(5));
      expect(summary.totalOffsetAmount, Decimal.fromInt(75));
      expect(summary.netAmount, Decimal.fromInt(25));
    });

    test('returns not-found when original does not exist', () async {
      final original = offsetOriginalTransactionFixture();

      when(
        () => repository.getById(original.id),
      ).thenAnswer((_) async => const Success<Transaction?>(null));

      final result = await useCase(original.id);

      expect(result.failureOrNull, isA<TransactionNotFoundFailure>());

      verifyNever(() => repository.getOffsetsForTransaction(any()));
    });
  });
}
