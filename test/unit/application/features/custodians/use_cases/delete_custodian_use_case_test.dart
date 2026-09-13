import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/delete_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('DeleteCustodianUseCase', () {
    late MockCustodianRepository repository;
    late DeleteCustodianUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = DeleteCustodianUseCase(repository);
    });

    test('returns the deleted custodian snapshot', () async {
      // Given
      final custodian = custodianFixture(
        id: 'delete',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.delete(custodian.id),
      ).thenAnswer((_) async => Success(custodian));

      // When
      final result = await useCase(custodian.id);

      // Then
      expect(result.valueOrNull, same(custodian));
      expect(result.valueOrNull?.deletedAt, isNotNull);
      verify(() => repository.delete(custodian.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final custodian = custodianFixture(id: 'missing');
      const failure = CustodianNotFoundFailure(message: 'missing');
      when(
        () => repository.delete(custodian.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
