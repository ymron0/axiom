@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/models/ledger_entry_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('LedgerEntryPersistenceModel', () {
    test('round-trips a transaction ledger entry', () {
      final entry = transactionFixture(
        id: 'transaction-1',
      ).ledgerEntries.single;

      final model = LedgerEntryPersistenceModel.fromEntity(entry);

      expect(
        LedgerEntryPersistenceModel.fromRecord(
          model.toRecord(),
          path: 'entries[0]',
        ).toEntity(),
        entry,
      );
    });

    test('round-trips a percentage fee expression', () {
      final assetId = AssetId.fromString('asset-fee');

      final amount = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('2.50'),
      );

      final entry = LedgerEntry.percentageFee(
        accountId: AccountId.fromString('account-fee'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        percentage: Decimal.parse('1.25'),
      );

      final model = LedgerEntryPersistenceModel.fromEntity(entry);

      final record = model.toRecord();

      expect(record.containsKey('feeExpression'), isTrue);
      expect(record.containsKey('feePercentage'), isFalse);

      final restored = LedgerEntryPersistenceModel.fromRecord(
        record,
        path: 'entries[0]',
      ).toEntity();

      expect(restored, entry);
      expect(restored.feeExpression, isA<PercentageFeeExpression>());
      expect(restored.feePercentage, Decimal.parse('1.25'));
      expect(restored.isPercentageFee, isTrue);
      expect(restored.isAssetAmountFee, isFalse);
    });

    test('round-trips an asset-amount fee expression', () {
      final assetId = AssetId.fromString('asset-fee');

      final amount = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('2.50'),
      );

      final entry = LedgerEntry.assetAmountFee(
        accountId: AccountId.fromString('account-fee'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
      );

      final record = LedgerEntryPersistenceModel.fromEntity(entry).toRecord();

      final restored = LedgerEntryPersistenceModel.fromRecord(
        record,
        path: 'entries[0]',
      ).toEntity();

      expect(restored, entry);
      expect(restored.feeExpression, isA<AssetAmountFeeExpression>());
      expect(restored.feeAssetAmount, amount);
      expect(restored.feePercentage, isNull);
      expect(restored.isAssetAmountFee, isTrue);
      expect(restored.isFixedFee, isTrue);
    });

    test('reads legacy percentage fee records', () {
      final assetId = AssetId.fromString('asset-fee');

      final amount = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('2.50'),
      );

      final entry = LedgerEntry.percentageFee(
        accountId: AccountId.fromString('account-fee'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        percentage: Decimal.parse('1.25'),
      );

      final record = LedgerEntryPersistenceModel.fromEntity(entry).toRecord()
        ..remove('feeExpression')
        ..['feePercentage'] = '1.25';

      final restored = LedgerEntryPersistenceModel.fromRecord(
        record,
        path: 'entries[0]',
      ).toEntity();

      expect(restored.feeExpression, isA<PercentageFeeExpression>());
      expect(restored.feePercentage, Decimal.parse('1.25'));
      expect(restored.isPercentageFee, isTrue);
    });

    test('reads legacy fixed fee records as asset-amount expressions', () {
      final assetId = AssetId.fromString('asset-fee');

      final amount = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('2.50'),
      );

      final entry = LedgerEntry.assetAmountFee(
        accountId: AccountId.fromString('account-fee'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
      );

      final record = LedgerEntryPersistenceModel.fromEntity(entry).toRecord()
        ..remove('feeExpression')
        ..remove('feePercentage');

      final restored = LedgerEntryPersistenceModel.fromRecord(
        record,
        path: 'entries[0]',
      ).toEntity();

      expect(restored.feeExpression, isA<AssetAmountFeeExpression>());
      expect(restored.feeAssetAmount, amount);
      expect(restored.isAssetAmountFee, isTrue);
    });

    test(
      'rejects records containing both new and legacy fee representations',
      () {
        final assetId = AssetId.fromString('asset-fee');

        final amount = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('2.50'),
        );

        final entry = LedgerEntry.percentageFee(
          accountId: AccountId.fromString('account-fee'),
          transactionAmount: amount,
          accountAmount: amount,
          valuationAmount: amount,
          percentage: Decimal.parse('1.25'),
        );

        final record = LedgerEntryPersistenceModel.fromEntity(entry).toRecord()
          ..['feePercentage'] = '1.25';

        expect(
          () => LedgerEntryPersistenceModel.fromRecord(
            record,
            path: 'entries[0]',
          ),
          throwsA(isA<PersistenceRecordException>()),
        );
      },
    );

    test(
      'rejects malformed nested amounts and invalid account identifiers',
      () {
        final record = LedgerEntryPersistenceModel.fromEntity(
          transactionFixture(id: 'transaction-1').ledgerEntries.single,
        ).toRecord();

        expect(
          () => LedgerEntryPersistenceModel.fromRecord(<String, Object?>{
            ...record,
            'transactionAmount': 'not-a-map',
          }, path: 'entries[0]'),
          throwsA(isA<PersistenceRecordException>()),
        );

        final invalid = LedgerEntryPersistenceModel.fromRecord(
          <String, Object?>{...record, 'accountId': ''},
          path: 'entries[0]',
        );

        expect(invalid.toEntity, throwsArgumentError);
      },
    );

    test('rejects malformed legacy percentage persistence data', () {
      final record = LedgerEntryPersistenceModel.fromEntity(
        transactionFixture(id: 'transaction-1').ledgerEntries.single,
      ).toRecord();

      expect(
        () => LedgerEntryPersistenceModel.fromRecord(<String, Object?>{
          ...record,
          'feePercentage': 'not-a-decimal',
        }, path: 'entries[0]'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects malformed new fee expression data', () {
      final record = LedgerEntryPersistenceModel.fromEntity(
        transactionFixture(id: 'transaction-1').ledgerEntries.single,
      ).toRecord();

      expect(
        () => LedgerEntryPersistenceModel.fromRecord(<String, Object?>{
          ...record,
          'feeExpression': <String, Object?>{
            'type': 'percentage',
            'percentage': 'invalid',
          },
        }, path: 'entries[0]'),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
