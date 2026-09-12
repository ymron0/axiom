import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_code_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetByCodeUseCase', () {
    late MockAssetRepository repository;
    late GetAssetByCodeUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = GetAssetByCodeUseCase(repository);
    });

    test('returns the matching asset from the injected repository', () async {
      // Given
      final code = AssetCode('AAA');
      final asset = currencyFixture(id: 'by-code-asset', code: 'AAA');
      when(
        () => repository.getByCode(code),
      ).thenAnswer((_) async => Success<Asset?>(asset));

      // When
      final result = await useCase.call(code);

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => repository.getByCode(code)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final code = AssetCode('AAA');
      const failure = AssetAlreadyExistsFailure(message: 'lookup failed');
      when(() => repository.getByCode(code)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(code);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
