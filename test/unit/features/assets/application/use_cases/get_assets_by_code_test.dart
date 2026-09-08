import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_code.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetsByCodeUseCase', () {
    test('returns only assets with the requested code', () async {
      // Given
      final repository = MockAssetRepository();
      final euro = currencyFixture();
      final code = AssetCode('EUR');
      when(
        () => repository.getByCode(code),
      ).thenAnswer((_) async => Success([euro]));
      final useCase = GetAssetsByCodeUseCase(repository);

      // When
      final result = await useCase.call(code);

      // Then
      expect(result.valueOrNull, [same(euro)]);
      verify(() => repository.getByCode(code)).called(1);
    });
  });
}
