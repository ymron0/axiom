@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/settings/data/models/settings_persistence_model.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsPersistenceModel', () {
    test('round-trips settings', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('EUR'),
        allowOverbudgetTransactions: false,
      );

      final model = SettingsPersistenceModel.fromEntity(settings);

      expect(
        model.toRecord(),
        <String, Object?>{
          'valuationCurrencyId': 'EUR',
          'allowOverbudgetTransactions': false,
        },
      );

      expect(
        SettingsPersistenceModel.fromRecord(
          model.toRecord(),
        ).toEntity(),
        settings,
      );
    });

    test(
      'defaults legacy records to allowing overbudget transactions',
      () {
        final entity = SettingsPersistenceModel.fromRecord(
          const <String, Object?>{
            'valuationCurrencyId': 'CHF',
          },
        ).toEntity();

        expect(entity.allowOverbudgetTransactions, isTrue);
      },
    );

    test('rejects invalid overbudget setting types', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(
          const <String, Object?>{
            'valuationCurrencyId': 'CHF',
            'allowOverbudgetTransactions': 'false',
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects null overbudget setting when the field exists', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(
          const <String, Object?>{
            'valuationCurrencyId': 'CHF',
            'allowOverbudgetTransactions': null,
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects missing and invalid valuation currency identifiers', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(
          const <String, Object?>{},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );

      expect(
        () => SettingsPersistenceModel.fromRecord(
          const <String, Object?>{
            'valuationCurrencyId': '',
          },
        ).toEntity(),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}