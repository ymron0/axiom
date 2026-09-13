import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:mocktail/mocktail.dart';

/// A mock account repository for application-layer tests.
class MockAccountRepository extends Mock implements AccountRepository {}
