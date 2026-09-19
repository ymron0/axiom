@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_persistence_model.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotPersistenceModel', () {
    test('round-trips account snapshot', () {
      final snapshot = _accountSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: model.recordKey,
        record: model.toRecord(),
      ).toEntity();

      expect(restored, snapshot);
    });

    test('round-trips custodian snapshot', () {
      final snapshot = _custodianSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: model.recordKey,
        record: model.toRecord(),
      ).toEntity();

      expect(restored, snapshot);
    });

    test('round-trips jar snapshot', () {
      final snapshot = _jarSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: model.recordKey,
        record: model.toRecord(),
      ).toEntity();

      expect(restored, snapshot);
    });

    test('writes stable account natural key', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      expect(model.recordKey, 'account|account-1|2026-09-19');
    });

    test('writes current record version', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = model.toRecord();

      expect(
        record[BalanceSnapshotPersistenceModel.recordVersionField],
        BalanceSnapshotPersistenceModel.currentRecordVersion,
      );

      expect(BalanceSnapshotPersistenceModel.currentRecordVersion, 1);
    });

    test('persists redundant subject query metadata', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = model.toRecord();

      expect(
        record[BalanceSnapshotPersistenceModel.subjectTypeField],
        'account',
      );

      expect(
        record[BalanceSnapshotPersistenceModel.subjectIdField],
        'account-1',
      );

      expect(
        record[BalanceSnapshotPersistenceModel.subjectKeyField],
        'account|account-1',
      );
    });

    test('persists snapshot date and numeric epoch-day index', () {
      final snapshot = _accountSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final record = model.toRecord();

      final expectedEpochDay =
          snapshot.snapshotDate.toDateTimeUtc().millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;

      expect(
        record[BalanceSnapshotPersistenceModel.snapshotDateField],
        '2026-09-19',
      );

      expect(
        record[BalanceSnapshotPersistenceModel.snapshotDateEpochDayField],
        expectedEpochDay,
      );
    });

    test('persists capture timestamp as UTC ISO-8601', () {
      final snapshot = BalanceSnapshot(
        subject: BalanceSnapshotSubject.account(
          AccountId.fromString('account-time'),
        ),
        snapshotDate: CalendarDate(2026, 9, 19),
        capturedAt: DateTime.parse('2026-09-20T04:00:00+02:00'),
        assetBalances: [_incoming('asset-eur', '100')],
        denominationAmount: _incoming('asset-eur', '100'),
        valuationAmount: _incoming('asset-chf', '95'),
      );

      final record = BalanceSnapshotPersistenceModel.fromEntity(
        snapshot,
      ).toRecord();

      expect(
        record[BalanceSnapshotPersistenceModel.capturedAtField],
        '2026-09-20T02:00:00.000Z',
      );
    });

    test('persists decimals as exact strings', () {
      final snapshot = BalanceSnapshot(
        subject: BalanceSnapshotSubject.account(
          AccountId.fromString('account-decimal'),
        ),
        snapshotDate: CalendarDate(2026, 9, 19),
        capturedAt: DateTime.utc(2026, 9, 20),
        assetBalances: [_incoming('asset-btc', '0.123456789123456789')],
        denominationAmount: _incoming('asset-eur', '100.123456789123456789'),
        valuationAmount: _incoming('asset-chf', '95.987654321987654321'),
      );

      final record = BalanceSnapshotPersistenceModel.fromEntity(
        snapshot,
      ).toRecord();

      final balances =
          record[BalanceSnapshotPersistenceModel.assetBalancesField]!
              as List<Object?>;

      final balance = balances.single as Map;

      expect(balance['amount'], '0.123456789123456789');

      final denomination =
          record[BalanceSnapshotPersistenceModel.denominationAmountField]!
              as Map;

      expect(denomination['amount'], '100.123456789123456789');

      final valuation =
          record[BalanceSnapshotPersistenceModel.valuationAmountField]! as Map;

      expect(valuation['amount'], '95.987654321987654321');
    });

    test('preserves account denomination separately from base valuation', () {
      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: BalanceSnapshotPersistenceModel.fromEntity(
          _accountSnapshot(),
        ).recordKey,
        record: BalanceSnapshotPersistenceModel.fromEntity(
          _accountSnapshot(),
        ).toRecord(),
      ).toEntity();

      expect(
        restored.denominationAmount.assetId,
        AssetId.fromString('asset-eur'),
      );

      expect(restored.denominationAmount.amount, Decimal.parse('180'));

      expect(restored.valuationAmount.assetId, AssetId.fromString('asset-chf'));

      expect(restored.valuationAmount.amount, Decimal.parse('171'));
    });

    test('custodian denomination equals base valuation after round trip', () {
      final snapshot = _custodianSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: model.recordKey,
        record: model.toRecord(),
      ).toEntity();

      expect(restored.denominationAmount, restored.valuationAmount);
    });

    test('jar denomination equals base valuation after round trip', () {
      final snapshot = _jarSnapshot();

      final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

      final restored = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: model.recordKey,
        record: model.toRecord(),
      ).toEntity();

      expect(restored.denominationAmount, restored.valuationAmount);
    });

    test('rejects unsupported record version', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.recordVersionField: 2,
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.recordVersionField,
          ),
        ),
      );
    });

    test('rejects missing record version', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{...model.toRecord()}
        ..remove(BalanceSnapshotPersistenceModel.recordVersionField);

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects subject type inconsistent with record key', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.subjectTypeField: 'custodian',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.subjectTypeField,
          ),
        ),
      );
    });

    test('rejects subject ID inconsistent with record key', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.subjectIdField: 'another-account',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.subjectIdField,
          ),
        ),
      );
    });

    test('rejects subject lookup key inconsistent with record key', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.subjectKeyField:
            'account|another-account',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.subjectKeyField,
          ),
        ),
      );
    });

    test('rejects snapshot date inconsistent with record key', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.snapshotDateField: '2026-09-18',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.snapshotDateField,
          ),
        ),
      );
    });

    test('rejects date index inconsistent with snapshot date', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.snapshotDateEpochDayField:
            model.snapshotDateEpochDay + 1,
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
          ),
        ),
      );
    });

    test('rejects malformed capture timestamp', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.capturedAtField: 'not-a-date',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects non-UTC capture timestamp', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.capturedAtField: '2026-09-20T02:00:00',
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects malformed asset-balance record', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.assetBalancesField: <Object?>[
          'not-a-record',
        ],
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            'assetBalances[0]',
          ),
        ),
      );
    });

    test('rejects malformed denomination amount', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final denomination = Map<String, Object?>.from(
        model.toRecord()[BalanceSnapshotPersistenceModel
                .denominationAmountField]!
            as Map,
      );

      denomination['amount'] = 'invalid';

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.denominationAmountField: denomination,
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            'denominationAmount.amount',
          ),
        ),
      );
    });

    test('rejects malformed valuation amount', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      final valuation = Map<String, Object?>.from(
        model.toRecord()[BalanceSnapshotPersistenceModel.valuationAmountField]!
            as Map,
      );

      valuation['direction'] = 'invalid';

      final record = <String, Object?>{
        ...model.toRecord(),
        BalanceSnapshotPersistenceModel.valuationAmountField: valuation,
      };

      expect(
        () => BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            'valuationAmount.direction',
          ),
        ),
      );
    });

    test(
      'rejects duplicate persisted asset balances during domain reconstruction',
      () {
        final model = BalanceSnapshotPersistenceModel.fromEntity(
          _accountSnapshot(),
        );

        final record = model.toRecord();

        final balances = List<Object?>.from(
          record[BalanceSnapshotPersistenceModel.assetBalancesField]! as List,
        );

        balances.add(Map<String, Object?>.from(balances.first! as Map));

        final corruptedRecord = <String, Object?>{
          ...record,
          BalanceSnapshotPersistenceModel.assetBalancesField: balances,
        };

        final corruptedModel = BalanceSnapshotPersistenceModel.fromRecord(
          recordKey: model.recordKey,
          record: corruptedRecord,
        );

        expect(
          corruptedModel.toEntity,
          throwsA(isA<PersistenceRecordException>()),
        );
      },
    );

    test('asset-balance model collection is immutable', () {
      final model = BalanceSnapshotPersistenceModel.fromEntity(
        _accountSnapshot(),
      );

      expect(() => model.assetBalances.clear(), throwsUnsupportedError);
    });
  });
}

BalanceSnapshot _accountSnapshot() {
  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.account(AccountId.fromString('account-1')),
    snapshotDate: CalendarDate(2026, 9, 19),
    capturedAt: DateTime.utc(2026, 9, 20, 2),
    assetBalances: [
      _incoming('asset-btc', '0.01'),
      _incoming('asset-usd', '100'),
    ],
    denominationAmount: _incoming('asset-eur', '180'),
    valuationAmount: _incoming('asset-chf', '171'),
  );
}

BalanceSnapshot _custodianSnapshot() {
  final total = _incoming('asset-chf', '15000');

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.custodian(
      CustodianId.fromString('custodian-1'),
    ),
    snapshotDate: CalendarDate(2026, 9, 19),
    capturedAt: DateTime.utc(2026, 9, 20, 2),
    assetBalances: [
      _incoming('asset-btc', '0.01'),
      _incoming('asset-chf', '5000'),
      _incoming('asset-usd', '100'),
    ],
    denominationAmount: total,
    valuationAmount: total,
  );
}

BalanceSnapshot _jarSnapshot() {
  final balance = _incoming('asset-chf', '2500');

  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.jar(JarId.fromString('jar-1')),
    snapshotDate: CalendarDate(2026, 9, 19),
    capturedAt: DateTime.utc(2026, 9, 20, 2),
    assetBalances: [balance],
    denominationAmount: balance,
    valuationAmount: balance,
  );
}

AssetAmount _incoming(String assetId, String amount) {
  return AssetAmount.incoming(
    assetId: AssetId.fromString(assetId),
    amount: Decimal.parse(amount),
  );
}
