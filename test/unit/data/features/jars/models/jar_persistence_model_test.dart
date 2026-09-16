@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/data/models/jar_persistence_model.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';

void main() {
  group('JarPersistenceModel', () {
    test('round-trips an active jar', () {
      final jar = jarFixture(id: 'jar-1');
      final model = JarPersistenceModel.fromEntity(jar);

      expect(
        JarPersistenceModel.fromRecord(
          recordKey: jar.id.value,
          record: model.toRecord(),
        ).toEntity(),
        jar,
      );
    });

    test('reconstructs persisted target records in order', () {
      final jar = jarFixture(
        id: 'jar-1',
        targets: <JarTarget>[
          JarTarget(
            amount: AssetAmount(
              assetId: AssetId.fromString('asset-1'),
              amount: Decimal.fromInt(100),
              direction: AssetAmountDirection.incoming,
            ),
            effectiveFrom: CalendarDate(2026, 1, 1),
          ),
        ],
      );
      final model = JarPersistenceModel.fromEntity(jar);

      expect(
        JarPersistenceModel.fromRecord(
          recordKey: jar.id.value,
          record: model.toRecord(),
        ).toEntity(),
        jar,
      );
    });

    test('rejects deleted jars and corrupt records', () {
      expect(
        () => JarPersistenceModel.fromEntity(
          jarFixture(id: 'jar-1', deletedAt: DateTime.utc(2026)),
        ),
        throwsStateError,
      );
      final record = JarPersistenceModel.fromEntity(
        jarFixture(id: 'jar-1'),
      ).toRecord();
      expect(
        () => JarPersistenceModel.fromRecord(
          recordKey: 'jar-1',
          record: <String, Object?>{...record, 'kind': 'invalid'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final deleted = JarPersistenceModel.fromRecord(
        recordKey: 'jar-1',
        record: <String, Object?>{
          ...record,
          'deletedAt': '2026-01-01T00:00:00.000Z',
        },
      );
      expect(deleted.toEntity, throwsA(isA<PersistenceRecordException>()));
      final invalidId = JarPersistenceModel.fromRecord(
        recordKey: '',
        record: record,
      );
      expect(invalidId.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('rejects non-UTC optional timestamps', () {
      final record = JarPersistenceModel.fromEntity(
        jarFixture(id: 'jar-1'),
      ).toRecord();

      expect(
        () => JarPersistenceModel.fromRecord(
          recordKey: 'jar-1',
          record: <String, Object?>{
            ...record,
            'archivedAt': '2026-01-01T00:00:00',
          },
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (exception) => exception.field,
            'field',
            'archivedAt',
          ),
        ),
      );
    });
  });
}
