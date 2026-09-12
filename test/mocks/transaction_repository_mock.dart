import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:mocktail/mocktail.dart';

/// A mock transaction repository for application-layer tests.
class MockTransactionRepository extends Mock implements TransactionRepository {}
