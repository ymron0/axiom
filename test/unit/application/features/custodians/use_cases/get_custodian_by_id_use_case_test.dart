import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('GetCustodianByIdUseCase', () {
    late MockCustodianRepository repository;
    late GetCustodianByIdUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = GetCustodianByIdUseCase(repository);
    });

    test('returns the custodian matching the ID', () async {
      // Given
      final custodian = custodianFixture(id: 'by-id');
      when(
        () => repository.getById(custodian.id),
      ).thenAnswer((_) async => Success<Custodian?>(custodian));

      // When
      final result = await useCase(custodian.id);

      // Then
      expect(result.valueOrNull, same(custodian));
      verify(() => repository.getById(custodian.id)).called(1);
    });

    test('returns null when the custodian is absent', () async {
      // Given
      final id = CustodianId.fromString('missing');
      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<Custodian?>(null));

      // When
      final result = await useCase(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = CustodianId.fromString('failure');
      const failure = CustodianNotFoundFailure(message: 'read failed');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
