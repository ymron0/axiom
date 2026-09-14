@Tags(['integration'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/accounts/data/repositories/in_memory_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:axiom/src/features/merchants/data/repositories/in_memory_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../fixtures/features/accounts/account_fixtures.dart';
import '../fixtures/features/custodians/custodian_fixtures.dart';
import '../fixtures/features/merchants/merchant_fixtures.dart';
import '../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  Transaction transactionWithMerchant({
    required String id,
    required MerchantId merchantId,
  }) {
    final base = transactionFixture(id: id);

    return Transaction(
      id: base.id,
      kind: base.kind,
      merchantId: merchantId,
      effectiveAt: base.effectiveAt,
      description: base.description,
      note: base.note,
      state: base.state,
      deletedAt: base.deletedAt,
      splits: base.splits,
      ledgerEntries: base.ledgerEntries,
      createdAt: base.createdAt,
      modifiedAt: base.modifiedAt,
      entityVersion: base.entityVersion,
    );
  }

  group('Cross-domain relationships', () {
    group('LedgerEntry -> Account', () {
      test(
        'uses the affected account denomination while preserving transaction '
        'and valuation currencies and direction',
        () {
          // Given
          final account = accountFixture(
            id: 'account-eur',
            denominationAssetId: 'asset-eur',
          );
          final settings = Settings(
            valuationCurrencyId: AssetId.fromString('asset-chf'),
          );
          final direction = AssetAmountDirection.outgoing;

          // When
          final entry = LedgerEntry(
            accountId: account.id,
            transactionAmount: AssetAmount(
              assetId: AssetId.fromString('asset-usd'),
              amount: Decimal.parse('100'),
              direction: direction,
            ),
            accountAmount: AssetAmount(
              assetId: account.denominationAssetId,
              amount: Decimal.parse('85.20'),
              direction: direction,
            ),
            valuationAmount: AssetAmount(
              assetId: settings.valuationCurrencyId,
              amount: Decimal.parse('79.40'),
              direction: direction,
            ),
            role: LedgerEntryRole.primary,
          );

          // Then
          expect(entry.accountId, account.id);
          expect(entry.accountAmount.assetId, account.denominationAssetId);
          expect(
            entry.transactionAmount.assetId,
            isNot(account.denominationAssetId),
          );
          expect(
            entry.transactionAmount.assetId,
            isNot(settings.valuationCurrencyId),
          );
          expect(entry.valuationAmount.assetId, settings.valuationCurrencyId);
          expect([
            entry.transactionAmount.direction,
            entry.accountAmount.direction,
            entry.valuationAmount.direction,
          ], everyElement(direction));
        },
      );
    });

    group('Transaction -> Merchant', () {
      test(
        'retains a required typed reference for normal and self merchants',
        () {
          // Given
          final merchant = merchantFixture(id: 'merchant-grocery-store');

          // When
          final normalTransaction = transactionWithMerchant(
            id: 'transaction-normal-merchant',
            merchantId: merchant.id,
          );
          final selfTransaction = transactionWithMerchant(
            id: 'transaction-self-merchant',
            merchantId: MerchantId.self,
          );

          // Then
          final MerchantId normalReference = normalTransaction.merchantId;
          final MerchantId selfReference = selfTransaction.merchantId;
          expect(normalReference, merchant.id);
          expect(selfReference, MerchantId.self);
        },
      );

      test(
        'resolves a normal referenced merchant through MerchantRepository',
        () async {
          // Given
          final merchant = merchantFixture(id: 'merchant-grocery-store');
          final transaction = transactionWithMerchant(
            id: 'transaction-normal-merchant',
            merchantId: merchant.id,
          );
          final MerchantRepository repository = InMemoryMerchantRepositoryImpl(
            initialMerchants: [merchant],
          );

          // When
          final result = await repository.getById(transaction.merchantId);

          // Then
          expect(result.valueOrNull, same(merchant));
        },
      );
    });

    group('Account -> Custodian', () {
      test(
        'allows multiple typed account references to one custodian',
        () async {
          // Given
          final custodian = custodianFixture(id: 'custodian-bank');
          final accounts = [
            accountFixture(
              id: 'account-eur',
              custodianId: custodian.id.value,
              denominationAssetId: 'asset-eur',
            ),
            accountFixture(
              id: 'account-usd',
              custodianId: custodian.id.value,
              denominationAssetId: 'asset-usd',
            ),
          ];
          final AccountRepository repository = InMemoryAccountRepositoryImpl(
            initialAccounts: accounts,
          );

          // When
          final resolved = await repository.getByCustodianId(custodian.id);

          // Then
          final CustodianId firstReference = accounts.first.custodianId;
          final CustodianId secondReference = accounts.last.custodianId;
          expect(firstReference, custodian.id);
          expect(secondReference, custodian.id);
          expect(resolved.valueOrNull, [
            same(accounts.first),
            same(accounts.last),
          ]);
        },
      );

      test(
        'aggregates externally resolved account values without mutable account '
        'state on Custodian',
        () async {
          // Given
          final custodian = custodianFixture(id: 'custodian-bank');
          final accounts = [
            accountFixture(
              id: 'account-eur',
              custodianId: custodian.id.value,
              denominationAssetId: 'asset-eur',
            ),
            accountFixture(
              id: 'account-usd',
              custodianId: custodian.id.value,
              denominationAssetId: 'asset-usd',
            ),
          ];
          final AccountRepository repository = InMemoryAccountRepositoryImpl(
            initialAccounts: accounts,
          );
          final settings = Settings(
            valuationCurrencyId: AssetId.fromString('asset-chf'),
          );
          const calculator = CustodianAggregationCalculator();

          // When
          final resolvedAccounts = (await repository.getByCustodianId(
            custodian.id,
          )).valueOrNull!;
          final valuesByAccountId = {
            accounts.first.id: Decimal.parse('95'),
            accounts.last.id: Decimal.parse('80'),
          };
          final accountValuations = resolvedAccounts
              .map(
                (account) => AccountValuation(
                  accountId: account.id,
                  custodianId: account.custodianId,
                  accountAmount: AssetAmount.incoming(
                    assetId: account.denominationAssetId,
                    amount: Decimal.parse('100'),
                  ),
                  valuationAmount: AssetAmount.incoming(
                    assetId: settings.valuationCurrencyId,
                    amount: valuesByAccountId[account.id]!,
                  ),
                ),
              )
              .toList(growable: false);
          final aggregation = calculator.calculate(
            custodianId: custodian.id,
            valuationCurrencyId: settings.valuationCurrencyId,
            accountValuations: accountValuations,
          );

          // Then
          expect(aggregation.custodianId, custodian.id);
          expect(aggregation.accountCount, resolvedAccounts.length);
          expect(aggregation.total.assetId, settings.valuationCurrencyId);
          expect(aggregation.total.amount, Decimal.parse('175'));
          expect(custodian.id, CustodianId.fromString('custodian-bank'));
        },
      );
    });
  });
}
