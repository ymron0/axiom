import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_failure_fixture.mapper.dart';

/// Test-only transaction-series failure used to verify failure propagation.
@MappableClass()
final class TestTransactionSeriesFailure
    extends Failure<TestTransactionSeriesFailure>
    with TestTransactionSeriesFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a test failure with optional details.
  const TestTransactionSeriesFailure({String? message}) : super(message);

  /// Stable test-only failure identifier.
  static const typeId = 'test.transactionSeriesFailure';

  @override
  TestTransactionSeriesFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
