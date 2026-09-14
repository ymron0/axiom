@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/create_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/invalid_merchant_name_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('CreateMerchantUseCase', () {
    late MockMerchantRepository repository;
    late CreateMerchantUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(merchantFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockMerchantRepository();
      useCase = CreateMerchantUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns the created merchant', () async {
      // Given
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call('  Test Merchant  ');

      // Then
      final merchant = result.valueOrNull!;
      expect(merchant, isA<Merchant>());
      expect(merchant.name, 'Test Merchant');
      expect(merchant.createdAt, timestamp);
      expect(merchant.modifiedAt, timestamp);
      expect(merchant.entityVersion, 1);
      expect(merchant.deletedAt, isNull);
      verify(() => repository.create(merchant)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = MerchantAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call('Test Merchant');

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test(
      'returns a failure without persisting when the name is blank',
      () async {
        // Given
        const name = '   ';

        // When
        final result = await useCase.call(name);

        // Then
        expect(
          result.failureOrNull,
          isA<InvalidMerchantNameFailure>()
              .having(
                (failure) => failure.type,
                'type',
                InvalidMerchantNameFailure.typeId,
              )
              .having((failure) => failure.message, 'message', isNotEmpty),
        );
        verifyNever(() => repository.create(any()));
      },
    );
  });
}
