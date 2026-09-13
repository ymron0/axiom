import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/update_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('UpdateMerchantUseCase', () {
    late MockMerchantRepository repository;
    late UpdateMerchantUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = UpdateMerchantUseCase(repository);
    });

    test('delegates the merchant to the repository', () async {
      // Given
      final merchant = merchantFixture(id: 'update');
      when(
        () => repository.update(merchant),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(merchant);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(merchant)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final merchant = merchantFixture(id: 'missing');
      const failure = MerchantNotFoundFailure(message: 'missing');
      when(() => repository.update(merchant)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(merchant);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
