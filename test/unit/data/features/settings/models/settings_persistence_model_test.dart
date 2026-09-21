@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/settings/data/models/settings_persistence_model.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';
import 'package:test/test.dart';

void main() {
  group('SettingsPersistenceModel', () {
    test('round-trips settings', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('EUR'),
        plannedTransactionGenerationHorizon:
            PlannedTransactionGenerationHorizon.oneYear,
        allowOverbudgetTransactions: false,
        allowNegativeJarBalances: false,
      );

      final model = SettingsPersistenceModel.fromEntity(settings);

      expect(model.toRecord(), <String, Object?>{
        'valuationCurrencyId': 'EUR',
        'plannedTransactionGenerationHorizon': 'oneYear',
        'allowOverbudgetTransactions': false,
        'allowNegativeJarBalances': false,
      });

      expect(
        SettingsPersistenceModel.fromRecord(model.toRecord()).toEntity(),
        settings,
      );
    });

    test(
      'defaults legacy records to two-year generation and permissive policies',
      () {
        final entity = SettingsPersistenceModel.fromRecord(
          const <String, Object?>{'valuationCurrencyId': 'CHF'},
        ).toEntity();

        expect(
          entity.plannedTransactionGenerationHorizon,
          PlannedTransactionGenerationHorizon.twoYears,
        );
        expect(entity.allowOverbudgetTransactions, isTrue);
        expect(entity.allowNegativeJarBalances, isTrue);
      },
    );

    test('defaults only missing fields for intermediate records', () {
      final entity = SettingsPersistenceModel.fromRecord(
        const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'allowOverbudgetTransactions': false,
        },
      ).toEntity();

      expect(
        entity.plannedTransactionGenerationHorizon,
        PlannedTransactionGenerationHorizon.twoYears,
      );
      expect(entity.allowOverbudgetTransactions, isFalse);
      expect(entity.allowNegativeJarBalances, isTrue);
    });

    test('rejects unsupported generation horizon', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'plannedTransactionGenerationHorizon': 'tenYears',
        }),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid generation horizon types', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'plannedTransactionGenerationHorizon': 2,
        }),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid overbudget setting types', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'allowOverbudgetTransactions': 'false',
        }),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid negative-jar setting types', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'allowNegativeJarBalances': 'false',
        }),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects null policy values when fields exist', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'allowOverbudgetTransactions': null,
        }),
        throwsA(isA<PersistenceRecordException>()),
      );

      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': 'CHF',
          'allowNegativeJarBalances': null,
        }),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects missing and invalid valuation currency identifiers', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{}),
        throwsA(isA<PersistenceRecordException>()),
      );

      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{
          'valuationCurrencyId': '',
        }).toEntity(),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
