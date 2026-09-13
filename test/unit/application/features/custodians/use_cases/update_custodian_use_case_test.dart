import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/update_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('UpdateCustodianUseCase', () {
    late MockCustodianRepository repository;
    late UpdateCustodianUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = UpdateCustodianUseCase(repository);
    });

    test('delegates the custodian to the repository', () async {
      // Given
      final custodian = custodianFixture(id: 'update');
      when(
        () => repository.update(custodian),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(custodian);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(custodian)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final custodian = custodianFixture(id: 'missing');
      const failure = CustodianNotFoundFailure(message: 'missing');
      when(() => repository.update(custodian)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(custodian);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
