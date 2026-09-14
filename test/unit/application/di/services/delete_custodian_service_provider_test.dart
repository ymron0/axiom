@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/delete_custodian_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/delete_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../mocks/delete_custodian_use_case_mock.dart';
import '../../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';

void main() {
  group('deleteCustodianServiceProvider', () {
    test('uses the configured account lookup and custodian deletion', () async {
      // Given
      final getAccounts = MockGetAccountsByCustodianIdUseCase();
      final deleteCustodian = MockDeleteCustodianUseCase();
      final custodian = custodianFixture(
        id: 'provider-custodian',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => getAccounts(custodian.id),
      ).thenAnswer((_) async => const Success([]));
      when(
        () => deleteCustodian(custodian.id),
      ).thenAnswer((_) async => Success<Custodian>(custodian));
      final container = ProviderContainer(
        overrides: [
          getAccountsByCustodianIdUseCaseProvider.overrideWithValue(
            getAccounts,
          ),
          deleteCustodianUseCaseProvider.overrideWithValue(deleteCustodian),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(deleteCustodianServiceProvider)(
        custodian.id,
      );

      // Then
      expect(result.valueOrNull, same(custodian));
      verify(() => getAccounts(custodian.id)).called(1);
      verify(() => deleteCustodian(custodian.id)).called(1);
    });
  });
}
