@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/resume_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('ResumeTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late ResumeTransactionSeriesUseCase useCase;

    final timestamp = DateTime.utc(2026, 9, 21, 12);

    setUpAll(() {
      registerFallbackValue(transactionSeriesFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockTransactionSeriesRepository();

      useCase = ResumeTransactionSeriesUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('resumes and persists a paused series', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'resume-series',
        isPaused: true,
      );

      final expected = series.resume(modifiedAt: timestamp);

      when(
        () => repository.getById(series.id),
      ).thenAnswer((_) async => Success<TransactionSeries?>(series));

      when(
        () => repository.update(expected),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(series.id);

      // Then
      final resumed = result.valueOrNull!;

      expect(resumed.isPaused, isFalse);
      expect(resumed.isGenerationEnabled, isTrue);
      expect(resumed.modifiedAt, timestamp);

      verify(() => repository.update(expected)).called(1);
    });

    test('does not resume an archived series', () async {
      // Given
      final archivedAt = DateTime.utc(2026, 9, 20);

      final series = transactionSeriesFixture(
        id: 'archived-series',
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      when(
        () => repository.getById(series.id),
      ).thenAnswer((_) async => Success<TransactionSeries?>(series));

      // When
      final result = await useCase(series.id);

      // Then
      expect(
        result.failureOrNull,
        isA<TransactionSeriesAlreadyArchivedFailure>(),
      );

      verifyNever(() => repository.update(any()));
    });

    test('is idempotent when the series is already resumed', () async {
      // Given
      final series = transactionSeriesFixture(id: 'already-running');

      when(
        () => repository.getById(series.id),
      ).thenAnswer((_) async => Success<TransactionSeries?>(series));

      // When
      final result = await useCase(series.id);

      // Then
      expect(result.valueOrNull, same(series));

      verifyNever(() => repository.update(any()));
    });

    test('returns not-found failure for a missing series', () async {
      // Given
      final id = transactionSeriesFixture(id: 'missing').id;

      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<TransactionSeries?>(null));

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, isA<TransactionSeriesNotFoundFailure>());

      verifyNever(() => repository.update(any()));
    });

    test('propagates lookup failures', () async {
      // Given
      final id = transactionSeriesFixture(id: 'lookup-failure').id;

      const failure = TestTransactionSeriesFailure(message: 'Lookup failed.');

      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => repository.update(any()));
    });

    test('propagates update failures', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'update-failure',
        isPaused: true,
      );

      final expected = series.resume(modifiedAt: timestamp);

      const failure = TestTransactionSeriesFailure(message: 'Update failed.');

      when(
        () => repository.getById(series.id),
      ).thenAnswer((_) async => Success<TransactionSeries?>(series));

      when(() => repository.update(expected)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(series.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
