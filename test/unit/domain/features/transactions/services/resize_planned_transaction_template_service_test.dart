@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('ResizePlannedTransactionTemplateService', () {
    const service = ResizePlannedTransactionTemplateService();

    test(
      'resizes primary representations and reconciles allocation splits',
      () {
        // Given
        final template = _template();

        final target = AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        );

        // When
        final resized = service(template: template, primaryAmount: target);

        // Then
        final primary = resized.ledgerEntries.singleWhere(
          (entry) => entry.role == LedgerEntryRole.primary,
        );

        expect(primary.transactionAmount.amount, Decimal.parse('40'));
        expect(
          primary.accountAmount.amount,
          Decimal.parse('33.333333333333333333'),
        );
        expect(primary.valuationAmount.amount, Decimal.parse('50'));

        final transactionSplitTotal = resized.splits.fold<Decimal>(
          Decimal.zero,
          (total, split) => total + split.transactionAmount.amount,
        );

        final valuationSplitTotal = resized.splits.fold<Decimal>(
          Decimal.zero,
          (total, split) => total + split.valuationAmount.amount,
        );

        expect(transactionSplitTotal, Decimal.parse('40'));
        expect(valuationSplitTotal, Decimal.parse('50'));

        final materialized = resized.instantiate(
          effectiveAt: DateTime.utc(2026, 9, 1),
          state: TransactionState.planned,
          clock: FixedClock(DateTime.utc(2026, 9, 1)),
        );

        expect(materialized.isSuccess, isTrue);
      },
    );

    test('leaves non-primary ledger entries unchanged', () {
      // Given
      final feeAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.parse('5'),
      );

      final template = _template(
        additionalEntries: [
          LedgerEntry(
            accountId: AccountId.fromString('fee-account'),
            transactionAmount: feeAmount,
            accountAmount: feeAmount,
            valuationAmount: feeAmount,
            role: LedgerEntryRole.fee,
          ),
        ],
      );

      // When
      final resized = service(
        template: template,
        primaryAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        ),
      );

      // Then
      final fee = resized.ledgerEntries.singleWhere(
        (entry) => entry.role == LedgerEntryRole.fee,
      );

      expect(fee.transactionAmount.amount, Decimal.parse('5'));
    });

    test('preserves unknown split amounts when resizing', () {
      // Given
      final unknownTransactionAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.fromInt(-1),
      );
      final unknownValuationAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-usd'),
        amount: Decimal.fromInt(-1),
      );
      final template = _template(
        splits: [
          TransactionSplit(
            transactionAmount: unknownTransactionAmount,
            valuationAmount: unknownValuationAmount,
            categoryId: CategoryId.fromString('category-1'),
          ),
        ],
      );

      // When
      final resized = service(
        template: template,
        primaryAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        ),
      );

      // Then
      expect(
        resized.splits.single.transactionAmount,
        same(unknownTransactionAmount),
      );
      expect(
        resized.splits.single.valuationAmount,
        same(unknownValuationAmount),
      );
    });

    test('preserves split amounts using an incompatible asset', () {
      // Given
      final transactionAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-usd'),
        amount: Decimal.parse('120'),
      );
      final valuationAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-eur'),
        amount: Decimal.parse('150'),
      );
      final template = _template(
        splits: [
          TransactionSplit(
            transactionAmount: transactionAmount,
            valuationAmount: valuationAmount,
            categoryId: CategoryId.fromString('category-1'),
          ),
        ],
      );

      // When
      final resized = service(
        template: template,
        primaryAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        ),
      );

      // Then
      expect(
        resized.splits.single.transactionAmount,
        same(transactionAmount),
      );
    });

    test('preserves split amounts when their original total is zero', () {
      // Given
      final transactionAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.zero,
      );
      final valuationAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-usd'),
        amount: Decimal.zero,
      );
      final template = _template(
        splits: [
          TransactionSplit(
            transactionAmount: transactionAmount,
            valuationAmount: valuationAmount,
            categoryId: CategoryId.fromString('category-1'),
          ),
        ],
      );

      // When
      final resized = service(
        template: template,
        primaryAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        ),
      );

      // Then
      expect(
        resized.splits.single.transactionAmount,
        same(transactionAmount),
      );
      expect(
        resized.splits.single.valuationAmount,
        same(valuationAmount),
      );
    });

    test('returns the original template when amount does not change', () {
      // Given
      final template = _template();

      // When
      final result = service(
        template: template,
        primaryAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('120'),
        ),
      );

      // Then
      expect(result, same(template));
    });

    test('rejects a template without exactly one primary ledger entry', () {
      // Given
      final template = _template(ledgerEntries: const []);

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'template',
          ),
        ),
      );
    });

    test('rejects a template with multiple primary ledger entries', () {
      // Given
      final template = _template(
        additionalEntries: [_primaryEntry()],
      );

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'template',
          ),
        ),
      );
    });

    test('rejects an unknown original primary amount', () {
      // Given
      final unknown = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.fromInt(-1),
      );
      final template = _template(
        primaryEntry: _primaryEntry(
          transactionAmount: unknown,
          accountAmount: unknown,
          valuationAmount: unknown,
        ),
      );

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'template',
          ),
        ),
      );
    });

    test('rejects a non-positive original primary amount', () {
      // Given
      final zero = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.zero,
      );
      final template = _template(
        primaryEntry: _primaryEntry(
          transactionAmount: zero,
          accountAmount: zero,
          valuationAmount: zero,
        ),
      );

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'template',
          ),
        ),
      );
    });

    test('rejects an unknown target amount', () {
      // Given
      final template = _template();

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.fromInt(-1),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'primaryAmount',
          ),
        ),
      );
    });

    test('rejects a target using a different asset', () {
      // Given
      final template = _template();

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.outgoing(
            assetId: AssetId.fromString('asset-usd'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'primaryAmount',
          ),
        ),
      );
    });

    test('rejects a target using a different direction', () {
      // Given
      final template = _template();

      // When / Then
      expect(
        () => service(
          template: template,
          primaryAmount: AssetAmount.incoming(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.parse('40'),
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'primaryAmount',
          ),
        ),
      );
    });
  });
}

TransactionTemplate _template({
  List<LedgerEntry> additionalEntries = const [],
  List<LedgerEntry>? ledgerEntries,
  LedgerEntry? primaryEntry,
  List<TransactionSplit>? splits,
}) {
  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.fromString('merchant'),
    splits: splits ?? [
      TransactionSplit(
        transactionAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('40'),
        ),
        valuationAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-usd'),
          amount: Decimal.parse('50'),
        ),
        categoryId: CategoryId.fromString('category-1'),
      ),
      TransactionSplit(
        transactionAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('80'),
        ),
        valuationAmount: AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-usd'),
          amount: Decimal.parse('100'),
        ),
        categoryId: CategoryId.fromString('category-2'),
      ),
    ],
    ledgerEntries: ledgerEntries ?? [
      primaryEntry ?? _primaryEntry(),
      ...additionalEntries,
    ],
  );
}

LedgerEntry _primaryEntry({
  AssetAmount? transactionAmount,
  AssetAmount? accountAmount,
  AssetAmount? valuationAmount,
}) {
  return LedgerEntry(
    accountId: AccountId.fromString('account'),
    transactionAmount: transactionAmount ??
        AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse('120'),
        ),
    accountAmount: accountAmount ??
        AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-eur'),
          amount: Decimal.parse('100'),
        ),
    valuationAmount: valuationAmount ??
        AssetAmount.outgoing(
          assetId: AssetId.fromString('asset-usd'),
          amount: Decimal.parse('150'),
        ),
    role: LedgerEntryRole.primary,
  );
}
