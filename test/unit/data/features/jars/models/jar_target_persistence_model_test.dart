@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/jars/data/models/jar_target_persistence_model.dart';
import 'package:test/test.dart';

void main() {
  group('JarTargetPersistenceModel', () {
    const record = <String, Object?>{
      'amount': <String, Object?>{
        'assetId': 'asset-1',
        'direction': 'incoming',
        'value': '42.25',
      },
      'effectiveFrom': '2026-01-01',
      'effectiveUntil': '2026-02-01',
      'targetDate': '2026-03-01',
    };

    test('round-trips an effective-dated target', () {
      final model = JarTargetPersistenceModel.fromRecord(record);

      expect(model.toRecord(), record);
      expect(model.toEntity().targetDate.toString(), '2026-03-01');
    });

    test('rejects malformed dates and invalid target ranges', () {
      expect(
        () => JarTargetPersistenceModel.fromRecord(
          <String, Object?>{...record, 'effectiveFrom': '2026-01-01T00:00:00Z'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final model = JarTargetPersistenceModel.fromRecord(
        <String, Object?>{...record, 'effectiveUntil': '2025-12-31'},
      );
      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('rejects calendar dates with invalid values', () {
      expect(
        () => JarTargetPersistenceModel.fromRecord(
          <String, Object?>{...record, 'effectiveFrom': '2026-13-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => JarTargetPersistenceModel.fromRecord(
          <String, Object?>{
            ...record,
            'effectiveFrom': '${List.filled(1000, '9').join()}-01-01',
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
