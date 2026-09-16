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
      final settings = Settings(valuationCurrencyId: AssetId.fromString('EUR'));
      final model = SettingsPersistenceModel.fromEntity(settings);

      expect(model.toRecord(), <String, Object?>{'valuationCurrencyId': 'EUR'});
      expect(SettingsPersistenceModel.fromRecord(model.toRecord()).toEntity(), settings);
    });

    test('rejects missing and invalid valuation currency identifiers', () {
      expect(
        () => SettingsPersistenceModel.fromRecord(const <String, Object?>{}),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => SettingsPersistenceModel.fromRecord(
          const <String, Object?>{'valuationCurrencyId': ''},
        ).toEntity(),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
