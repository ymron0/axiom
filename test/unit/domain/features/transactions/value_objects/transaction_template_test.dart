@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_template_instantiation_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionTemplate', () {
    test('stores reusable transaction data and normalizes optional text', () {
      final template = TransactionTemplate(
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        description: '  Rent  ',
        note: '  Monthly apartment rent  ',
        splits: const [],
        ledgerEntries: [_expenseEntry()],
      );

      expect(template.kind, TransactionKind.expense);
      expect(template.merchantId, same(MerchantId.self));
      expect(template.description, 'Rent');
      expect(template.note, 'Monthly apartment rent');
      expect(template.splits, isEmpty);
      expect(template.ledgerEntries, hasLength(1));
    });

    test('preserves omitted optional text as null', () {
      final template = _template();

      expect(template.description, isNull);
      expect(template.note, isNull);
    });

    test('rejects blank optional text', () {
      expect(
        () => _template(description: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'description',
          ),
        ),
      );

      expect(
        () => _template(note: '\t'),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'note'),
        ),
      );
    });

    test('defensively copies ledger entries and splits', () {
      final entries = <LedgerEntry>[_expenseEntry()];
      final splits = <TransactionSplit>[];

      final template = TransactionTemplate(
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        splits: splits,
        ledgerEntries: entries,
      );

      entries.clear();
      splits.add(_split());

      expect(template.ledgerEntries, hasLength(1));
      expect(template.splits, isEmpty);
    });

    test('exposes ledger entries and splits as immutable collections', () {
      final template = TransactionTemplate(
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        splits: [_split()],
        ledgerEntries: [_expenseEntry()],
      );

      expect(
        () => template.ledgerEntries.add(_expenseEntry()),
        throwsUnsupportedError,
      );

      expect(() => template.splits.add(_split()), throwsUnsupportedError);
    });

    test(
      'materializes a valid template as an ordinary planned transaction',
      () {
        final now = DateTime.utc(2026, 9, 17, 10);
        final effectiveAt = DateTime.parse('2026-10-01T08:30:00+02:00');
        final template = _template(description: 'Rent', note: 'October');

        final result = template.instantiate(
          effectiveAt: effectiveAt,
          clock: FixedClock(now),
        );

        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);

        final transaction = result.valueOrNull;

        expect(transaction, isA<Transaction>());
        expect(transaction!.kind, TransactionKind.expense);
        expect(transaction.merchantId, same(MerchantId.self));
        expect(transaction.description, 'Rent');
        expect(transaction.note, 'October');
        expect(transaction.state, TransactionState.planned);
        expect(transaction.effectiveAt, effectiveAt.toUtc());
        expect(transaction.createdAt, now);
        expect(transaction.modifiedAt, now);
        expect(transaction.entityVersion, 1);
        expect(transaction.deletedAt, isNull);
      },
    );

    test(
      'allows the occurrence workflow to select actual state explicitly',
      () {
        final result = _template().instantiate(
          effectiveAt: DateTime.utc(2026, 9, 17),
          state: TransactionState.actual,
          clock: FixedClock(DateTime.utc(2026, 9, 17)),
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.state, TransactionState.actual);
      },
    );

    test('uses the default transaction clock when none is supplied', () {
      final result = _template().instantiate(
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.createdAt.isUtc, isTrue);
      expect(result.valueOrNull!.modifiedAt, result.valueOrNull!.createdAt);
    });

    test(
      'translates transaction aggregate validation into a typed failure',
      () {
        final invalidTemplate = TransactionTemplate(
          kind: TransactionKind.expense,
          merchantId: MerchantId.self,
          splits: const [],
          ledgerEntries: [_expenseEntry(incoming: true)],
        );

        final result = invalidTemplate.instantiate(
          effectiveAt: DateTime.utc(2026, 9, 17),
          clock: FixedClock(DateTime.utc(2026, 9, 17)),
        );

        expect(result.isFailure, isTrue);
        expect(
          result.failureOrNull,
          isA<TransactionTemplateInstantiationFailure>(),
        );
        expect(result.failureOrNull!.message, contains('outgoing'));
        expect(result.valueOrNull, isNull);
      },
    );
  });
}

TransactionTemplate _template({String? description, String? note}) {
  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    description: description,
    note: note,
    splits: const [],
    ledgerEntries: [_expenseEntry()],
  );
}

LedgerEntry _expenseEntry({bool incoming = false}) {
  final amount = incoming
      ? AssetAmount.incoming(assetId: _assetId, amount: Decimal.parse('100'))
      : AssetAmount.outgoing(assetId: _assetId, amount: Decimal.parse('100'));

  return LedgerEntry(
    accountId: AccountId.fromString('account-1'),
    transactionAmount: amount,
    accountAmount: amount,
    valuationAmount: amount,
    role: LedgerEntryRole.primary,
  );
}

TransactionSplit _split() {
  final amount = AssetAmount.outgoing(
    assetId: _assetId,
    amount: Decimal.parse('100'),
  );

  return TransactionSplit(
    transactionAmount: amount,
    valuationAmount: amount,
    categoryId: CategoryId.fromString('category-1'),
    jarId: null,
  );
}

final AssetId _assetId = AssetId.fromString('asset-chf');
