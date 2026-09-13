import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/delete_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('DeleteMerchantUseCase', () {
    late MockMerchantRepository repository;
    late DeleteMerchantUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = DeleteMerchantUseCase(repository);
    });

    test('returns the deleted merchant snapshot', () async {
      // Given
      final merchant = merchantFixture(
        id: 'delete',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.delete(merchant.id),
      ).thenAnswer((_) async => Success(merchant));

      // When
      final result = await useCase.call(merchant.id);

      // Then
      expect(result.valueOrNull, same(merchant));
      expect(result.valueOrNull?.deletedAt, isNotNull);
      verify(() => repository.delete(merchant.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final merchant = merchantFixture(id: 'missing');
      const failure = MerchantNotFoundFailure(message: 'missing');
      when(
        () => repository.delete(merchant.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(merchant.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
