@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  group('ValidateJarTargetCurrenciesService', () {
    late MockGetSettingsUseCase getSettings;
    late ValidateJarTargetCurrenciesService service;
    final valuationCurrencyId = AssetId.fromString('currency-chf');

    setUp(() {
      getSettings = MockGetSettingsUseCase();
      service = ValidateJarTargetCurrenciesService(getSettings: getSettings);
    });

    test('accepts a jar without targets without loading settings', () async {
      final result = await service(const []);

      expect(result.isSuccess, isTrue);
      verifyNever(() => getSettings());
    });

    test('accepts targets using the valuation currency', () async {
      when(() => getSettings()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: valuationCurrencyId)),
      );

      final result = await service([_target(valuationCurrencyId)]);

      expect(result.isSuccess, isTrue);
    });

    test('rejects targets using another currency', () async {
      when(() => getSettings()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: valuationCurrencyId)),
      );

      final result = await service([_target(AssetId.fromString('currency-eur'))]);

      expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
    });

    test('propagates settings failures unchanged', () async {
      const failure = SettingsRepositoryFailure(message: 'settings failed');
      when(() => getSettings()).thenAnswer((_) async => failure);

      final result = await service([_target(valuationCurrencyId)]);

      expect(result.failureOrNull, same(failure));
    });

    test('returns not-initialized when settings are absent', () async {
      when(() => getSettings()).thenAnswer((_) async => const Success(null));

      final result = await service([_target(valuationCurrencyId)]);

      expect(result.isFailure, isTrue);
    });
  });
}

JarTarget _target(AssetId assetId) {
  return JarTarget(
    amount: AssetAmount(
      assetId: assetId,
      amount: Decimal.one,
      direction: AssetAmountDirection.incoming,
    ),
    effectiveFrom: CalendarDate(2026, 1, 1),
  );
}
