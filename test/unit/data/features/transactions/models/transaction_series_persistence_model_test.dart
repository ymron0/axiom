@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_series_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesPersistenceModel', () {
    test('round-trips the complete transaction-series definition', () {
      // Given
      final archivedAt = DateTime.utc(2026, 4, 1);

      final defaultTemplate = _template(
        merchantId: 'merchant-default',
        accountId: 'account-default',
        categoryId: 'category-default',
        jarId: 'jar-default',
        description: 'Default',
        amount: '120',
      );

      final replacementTemplate = _template(
        merchantId: 'merchant-replacement',
        accountId: 'account-replacement',
        categoryId: 'category-replacement',
        jarId: 'jar-replacement',
        description: 'Replacement',
        amount: '80',
      );

      final series = TransactionSeries(
        id: TransactionSeriesId.fromString('series-complete'),
        template: defaultTemplate,
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          end: RecurrenceEnd(
            until: CalendarDate(2027, 1, 1),
            count: 12,
            amount: RecurrenceAmountEnd(
              targetAmount: AssetAmount(
                assetId: AssetId.fromString('asset-chf'),
                amount: Decimal.parse('1000'),
                direction: AssetAmountDirection.outgoing,
              ),
              completion: RecurrenceAmountCompletion.exactTarget,
            ),
          ),
        ),
        exceptions: [
          RecurrenceException.replace(
            scheduledOn: CalendarDate(2026, 2, 1),
            replacementOn: CalendarDate(2026, 2, 2),
            replacementTemplate: replacementTemplate,
          ),
        ],
        archivedAt: archivedAt,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: archivedAt,
        entityVersion: 3,
      );

      // When
      final record = TransactionSeriesPersistenceModel.fromEntity(
        series,
      ).toRecord();

      final restored = TransactionSeriesPersistenceModel.fromRecord(
        recordKey: series.id.value,
        record: record,
      ).toEntity();

      // Then
      expect(restored.id, series.id);
      expect(restored.template.description, 'Default');
      expect(
        restored.template.merchantId,
        MerchantId.fromString('merchant-default'),
      );
      expect(restored.recurrenceRule.frequency, RecurrenceFrequency.monthly);
      expect(restored.recurrenceRule.interval, 1);
      expect(restored.recurrenceRule.end?.count, 12);
      expect(restored.recurrenceRule.end?.until.toString(), '2027-01-01');
      expect(
        restored.recurrenceRule.end?.amount?.targetAmount.amount,
        Decimal.parse('1000'),
      );
      expect(
        restored.recurrenceRule.end?.amount?.completion,
        RecurrenceAmountCompletion.exactTarget,
      );

      expect(restored.exceptions, hasLength(1));
      expect(restored.exceptions.single.scheduledOn.toString(), '2026-02-01');
      expect(restored.exceptions.single.replacementOn.toString(), '2026-02-02');
      expect(
        restored.exceptions.single.replacementTemplate?.merchantId,
        MerchantId.fromString('merchant-replacement'),
      );

      expect(restored.archivedAt, archivedAt);
      expect(restored.entityVersion, 3);
      expect(() => restored.exceptions.clear(), throwsUnsupportedError);
    });

    test('round-trips nullable recurrence and lifecycle values', () {
      // Given
      final series = _series(id: 'minimal');

      // When
      final record = TransactionSeriesPersistenceModel.fromEntity(
        series,
      ).toRecord();

      final restored = TransactionSeriesPersistenceModel.fromRecord(
        recordKey: series.id.value,
        record: record,
      ).toEntity();

      // Then
      expect(restored.archivedAt, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.exceptions, isEmpty);
      expect(restored.recurrenceRule.end, isNull);
    });

    test('rejects deleted domain snapshots', () {
      // Given
      final deleted = _series(
        id: 'deleted',
        deletedAt: DateTime.utc(2026, 2, 1),
      );

      // Then
      expect(
        () => TransactionSeriesPersistenceModel.fromEntity(deleted),
        throwsStateError,
      );
    });

    test('rejects malformed nested recurrence data', () {
      // Given
      final series = _series(id: 'invalid-frequency');

      final record = TransactionSeriesPersistenceModel.fromEntity(
        series,
      ).toRecord();

      final recurrenceRule = Map<String, Object?>.from(
        record['recurrenceRule']! as Map,
      );

      recurrenceRule['frequency'] = 'unsupported';
      record['recurrenceRule'] = recurrenceRule;

      // Then
      expect(
        () => TransactionSeriesPersistenceModel.fromRecord(
          recordKey: series.id.value,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects deleted snapshots remaining in persistence', () {
      // Given
      final series = _series(id: 'persisted-deleted');

      final record = TransactionSeriesPersistenceModel.fromEntity(
        series,
      ).toRecord();

      record['deletedAt'] = DateTime.utc(2026, 2, 1).toIso8601String();

      // When
      final model = TransactionSeriesPersistenceModel.fromRecord(
        recordKey: series.id.value,
        record: record,
      );

      // Then
      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('translates persisted aggregate invariant violations', () {
      // Given
      final series = _series(
        id: 'invalid-exception-date',
        exceptions: [
          RecurrenceException.skip(
            scheduledOn: CalendarDate(2026, 1, 1),
          ),
        ],
      );

      final record = TransactionSeriesPersistenceModel.fromEntity(
        series,
      ).toRecord();
      record['exceptions'] = <Object?>[
        <String, Object?>{
          'scheduledOn': '2026-01-02',
          'kind': 'skip',
          'replacementOn': null,
          'replacementTemplate': null,
        },
      ];

      final model = TransactionSeriesPersistenceModel.fromRecord(
        recordKey: series.id.value,
        record: record,
      );

      // When / Then
      expect(
        model.toEntity,
        throwsA(
          isA<PersistenceRecordException>().having(
            (exception) => exception.reason,
            'reason',
            'Persisted transaction series violates current domain invariants.',
          ),
        ),
      );
    });

  });
}

TransactionSeries _series({
  required String id,
  DateTime? archivedAt,
  DateTime? deletedAt,
  List<RecurrenceException> exceptions = const [],
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return TransactionSeries(
    id: TransactionSeriesId.fromString(id),
    template: _template(),
    recurrenceRule: RecurrenceRule(
      startsOn: CalendarDate(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
    ),
    exceptions: exceptions,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: archivedAt ?? createdAt,
    entityVersion: 1,
  );
}

TransactionTemplate _template({
  String merchantId = 'merchant-default',
  String accountId = 'account-default',
  String? categoryId,
  String? jarId,
  String? description = 'Template',
  String amount = '120',
}) {
  final transactionAmount = AssetAmount(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse(amount),
    direction: AssetAmountDirection.outgoing,
  );

  final splits = categoryId == null && jarId == null
      ? <TransactionSplit>[]
      : <TransactionSplit>[
          TransactionSplit(
            transactionAmount: transactionAmount,
            valuationAmount: transactionAmount,
            categoryId: categoryId == null
                ? null
                : CategoryId.fromString(categoryId),
            jarId: jarId == null ? null : JarId.fromString(jarId),
          ),
        ];

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.fromString(merchantId),
    description: description,
    note: 'Note',
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString(accountId),
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: transactionAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}
