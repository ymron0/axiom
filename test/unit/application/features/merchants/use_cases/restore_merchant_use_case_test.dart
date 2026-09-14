@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/restore_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('RestoreMerchantUseCase', () {
    late MockMerchantRepository repository;
    late RestoreMerchantUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = RestoreMerchantUseCase(repository);
    });

    test('delegates the deleted snapshot to the repository', () async {
      // Given
      final merchant = merchantFixture(
        id: 'restore',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.restore(merchant),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(merchant);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(merchant)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final merchant = merchantFixture(
        id: 'existing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = MerchantAlreadyExistsFailure(message: 'existing');
      when(() => repository.restore(merchant)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(merchant);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
