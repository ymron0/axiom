import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock custodian-account lookup use case for application-service tests.
class MockGetAccountsByCustodianIdUseCase extends Mock
    implements GetAccountsByCustodianIdUseCase {}
