@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/restore_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('RestoreCustodianUseCase', () {
    late MockCustodianRepository repository;
    late RestoreCustodianUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = RestoreCustodianUseCase(repository);
    });

    test('delegates the deleted snapshot to the repository', () async {
      // Given
      final custodian = custodianFixture(
        id: 'restore',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.restore(custodian),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(custodian);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(custodian)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final custodian = custodianFixture(
        id: 'existing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = CustodianAlreadyExistsFailure(message: 'existing');
      when(() => repository.restore(custodian)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(custodian);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
