@Tags(['application'])
library;

import 'package:axiom/src/application/services/delete_custodian_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_in_use_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../mocks/delete_custodian_use_case_mock.dart';
import '../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';

void main() {
  group('DeleteCustodianService', () {
    late MockGetAccountsByCustodianIdUseCase getAccounts;
    late MockDeleteCustodianUseCase deleteCustodian;
    late DeleteCustodianService service;

    setUp(() {
      getAccounts = MockGetAccountsByCustodianIdUseCase();
      deleteCustodian = MockDeleteCustodianUseCase();
      service = DeleteCustodianService(
        getAccounts: getAccounts,
        deleteCustodian: deleteCustodian,
      );
    });

    test('deletes a custodian with no associated accounts', () async {
      // Given
      final custodian = custodianFixture(
        id: 'unused-custodian',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => getAccounts(custodian.id),
      ).thenAnswer((_) async => const Success([]));
      when(
        () => deleteCustodian(custodian.id),
      ).thenAnswer((_) async => Success<Custodian>(custodian));

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.valueOrNull, same(custodian));
      verify(() => getAccounts(custodian.id)).called(1);
      verify(() => deleteCustodian(custodian.id)).called(1);
    });

    test('does not delete a custodian with associated accounts', () async {
      // Given
      final custodian = custodianFixture(id: 'used-custodian');
      final account = accountFixture(
        id: 'associated-account',
        custodianId: custodian.id.value,
      );
      when(
        () => getAccounts(custodian.id),
      ).thenAnswer((_) async => Success([account]));

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, isA<CustodianInUseFailure>());
      expect(result.failureOrNull?.message, contains(custodian.id.value));
      verify(() => getAccounts(custodian.id)).called(1);
      verifyNever(() => deleteCustodian(custodian.id));
    });

    test('propagates account lookup failures without deleting', () async {
      // Given
      final custodian = custodianFixture(id: 'lookup-failure');
      const failure = AccountNotFoundFailure(message: 'lookup failed');
      when(
        () => getAccounts(custodian.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => deleteCustodian(custodian.id));
    });

    test('propagates custodian deletion failures', () async {
      // Given
      final custodian = custodianFixture(id: 'missing-custodian');
      const failure = CustodianNotFoundFailure(message: 'missing');
      when(
        () => getAccounts(custodian.id),
      ).thenAnswer((_) async => const Success([]));
      when(() => deleteCustodian(custodian.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => deleteCustodian(custodian.id)).called(1);
    });
  });
}
