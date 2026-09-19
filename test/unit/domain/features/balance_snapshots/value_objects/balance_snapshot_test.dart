@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshot', () {
    group('account snapshots', () {
      test('supports multiple asset balances with one valuation', () {
        final snapshot = _accountSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-btc', amount: '0.5'),
            _incoming(assetId: 'asset-usd', amount: '1200'),
            _incoming(assetId: 'asset-aapl', amount: '12'),
          ],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '18450'),
        );

        expect(snapshot.subject.isAccount, isTrue);
        expect(snapshot.assetBalances, hasLength(3));

        expect(
          snapshot.valuationAmount.assetId,
          AssetId.fromString('asset-chf'),
        );

        expect(snapshot.valuationAmount.amount, Decimal.parse('18450'));
      });

      test('supports account valuation in a different currency', () {
        final snapshot = _accountSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-usd', amount: '1000'),
            _incoming(assetId: 'asset-msft', amount: '5'),
          ],
          valuationAmount: _incoming(assetId: 'asset-eur', amount: '2650'),
        );

        expect(
          snapshot.valuationAmount.assetId,
          AssetId.fromString('asset-eur'),
        );
      });

      test('supports an account with no current holdings', () {
        final snapshot = _accountSnapshot(
          assetBalances: const [],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '0'),
        );

        expect(snapshot.assetBalances, isEmpty);
        expect(snapshot.valuationAmount.amount, Decimal.zero);
      });
    });

    group('custodian snapshots', () {
      test('supports aggregated balances from multiple accounts', () {
        final snapshot = _custodianSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-btc', amount: '0.5'),
            _incoming(assetId: 'asset-usd', amount: '1200'),
            _incoming(assetId: 'asset-eur', amount: '500'),
            _incoming(assetId: 'asset-vwce', amount: '20'),
          ],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '21080'),
        );

        expect(snapshot.subject.isCustodian, isTrue);
        expect(snapshot.assetBalances, hasLength(4));

        expect(
          snapshot.valuationAmount.assetId,
          AssetId.fromString('asset-chf'),
        );
      });

      test('supports an empty custodian with zero valuation', () {
        final snapshot = _custodianSnapshot(
          assetBalances: const [],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '0'),
        );

        expect(snapshot.assetBalances, isEmpty);
        expect(snapshot.valuationAmount.amount, Decimal.zero);
      });
    });

    group('jar snapshots', () {
      test('stores a jar balance and valuation', () {
        final snapshot = _jarSnapshot(
          assetBalances: [_incoming(assetId: 'asset-chf', amount: '2500')],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '2500'),
        );

        expect(snapshot.subject.isJar, isTrue);
        expect(snapshot.assetBalances, hasLength(1));

        expect(snapshot.assetBalances.single, snapshot.valuationAmount);
      });

      test('supports a negative jar balance', () {
        final snapshot = _jarSnapshot(
          assetBalances: [_outgoing(assetId: 'asset-chf', amount: '50')],
          valuationAmount: _outgoing(assetId: 'asset-chf', amount: '50'),
        );

        expect(snapshot.assetBalances.single.isOutgoing, isTrue);
        expect(snapshot.valuationAmount.isOutgoing, isTrue);
      });
    });

    group('snapshot metadata', () {
      test('stores the represented calendar date', () {
        final snapshot = _accountSnapshot(
          snapshotDate: CalendarDate(2026, 7, 12),
        );

        expect(snapshot.snapshotDate, CalendarDate(2026, 7, 12));
      });

      test('normalizes capture timestamp to UTC', () {
        final capturedAt = DateTime.parse('2026-09-19T18:30:00+02:00');

        final snapshot = _accountSnapshot(capturedAt: capturedAt);

        expect(snapshot.capturedAt, capturedAt.toUtc());
        expect(snapshot.capturedAt.isUtc, isTrue);
      });

      test(
        'allows historical snapshot to be captured after represented date',
        () {
          final snapshot = _accountSnapshot(
            snapshotDate: CalendarDate(2026, 7, 12),
            capturedAt: DateTime.utc(2026, 9, 19, 16, 30),
          );

          expect(snapshot.snapshotDate, CalendarDate(2026, 7, 12));

          expect(snapshot.capturedAt, DateTime.utc(2026, 9, 19, 16, 30));
        },
      );
    });

    group('balance semantics', () {
      test('supports positive asset positions', () {
        final snapshot = _accountSnapshot(
          assetBalances: [_incoming(assetId: 'asset-usd', amount: '100')],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '80'),
        );

        final balance = snapshot.assetBalances.single;

        expect(balance.isIncoming, isTrue);
        expect(balance.amount, Decimal.parse('100'));
      });

      test('supports negative asset positions', () {
        final snapshot = _accountSnapshot(
          assetBalances: [_outgoing(assetId: 'asset-usd', amount: '100')],
          valuationAmount: _outgoing(assetId: 'asset-chf', amount: '80'),
        );

        final balance = snapshot.assetBalances.single;

        expect(balance.isOutgoing, isTrue);
        expect(balance.amount, Decimal.parse('100'));
      });

      test('supports negative total valuation', () {
        final snapshot = _custodianSnapshot(
          assetBalances: [_outgoing(assetId: 'asset-usd', amount: '1000')],
          valuationAmount: _outgoing(assetId: 'asset-chf', amount: '800'),
        );

        expect(snapshot.valuationAmount.isOutgoing, isTrue);

        expect(snapshot.valuationAmount.amount, Decimal.parse('800'));
      });

      test('rejects an unknown asset balance', () {
        expect(
          () => _accountSnapshot(
            assetBalances: [
              AssetAmount.incoming(
                assetId: AssetId.fromString('asset-usd'),
                amount: Decimal.fromInt(-1),
              ),
            ],
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'assetBalances',
            ),
          ),
        );
      });

      test('rejects duplicate asset balances', () {
        expect(
          () => _accountSnapshot(
            assetBalances: [
              _incoming(assetId: 'asset-usd', amount: '100'),
              _incoming(assetId: 'asset-usd', amount: '200'),
            ],
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'assetBalances',
            ),
          ),
        );
      });

      test('rejects duplicate assets with opposing directions', () {
        expect(
          () => _accountSnapshot(
            assetBalances: [
              _incoming(assetId: 'asset-usd', amount: '100'),
              _outgoing(assetId: 'asset-usd', amount: '25'),
            ],
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'assetBalances',
            ),
          ),
        );
      });

      test('rejects an unknown valuation amount', () {
        expect(
          () => _accountSnapshot(
            valuationAmount: AssetAmount.incoming(
              assetId: AssetId.fromString('asset-chf'),
              amount: Decimal.fromInt(-1),
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'valuationAmount',
            ),
          ),
        );
      });

      test('rejects non-zero valuation for an empty position', () {
        expect(
          () => _accountSnapshot(
            assetBalances: const [],
            valuationAmount: _incoming(assetId: 'asset-chf', amount: '1'),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'valuationAmount',
            ),
          ),
        );
      });

      test(
        'requires direct valuation to equal the only balance when assets match',
        () {
          expect(
            () => _accountSnapshot(
              assetBalances: [_incoming(assetId: 'asset-chf', amount: '100')],
              valuationAmount: _incoming(assetId: 'asset-chf', amount: '99'),
            ),
            throwsA(
              isA<ArgumentError>().having(
                (error) => error.name,
                'name',
                'valuationAmount',
              ),
            ),
          );
        },
      );

      test(
        'requires direct valuation direction to equal the balance direction',
        () {
          expect(
            () => _accountSnapshot(
              assetBalances: [_incoming(assetId: 'asset-chf', amount: '100')],
              valuationAmount: _outgoing(assetId: 'asset-chf', amount: '100'),
            ),
            throwsA(
              isA<ArgumentError>().having(
                (error) => error.name,
                'name',
                'valuationAmount',
              ),
            ),
          );
        },
      );

      test('accepts an exact direct valuation', () {
        final snapshot = _accountSnapshot(
          assetBalances: [_incoming(assetId: 'asset-chf', amount: '100')],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '100'),
        );

        expect(snapshot.assetBalances.single, snapshot.valuationAmount);
      });

      test('does not require one matching-currency balance to equal total '
          'valuation when other assets exist', () {
        final snapshot = _accountSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-chf', amount: '100'),
            _incoming(assetId: 'asset-usd', amount: '100'),
          ],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '180'),
        );

        expect(snapshot.valuationAmount.amount, Decimal.parse('180'));
      });
    });

    group('immutability and canonicalization', () {
      test('defensively copies asset balances', () {
        final balances = [_incoming(assetId: 'asset-usd', amount: '100')];

        final snapshot = _accountSnapshot(assetBalances: balances);

        balances.add(_incoming(assetId: 'asset-btc', amount: '0.5'));

        expect(snapshot.assetBalances, hasLength(1));
      });

      test('exposes asset balances as immutable', () {
        final snapshot = _accountSnapshot();

        expect(
          () => snapshot.assetBalances.add(
            _incoming(assetId: 'asset-btc', amount: '0.5'),
          ),
          throwsUnsupportedError,
        );
      });

      test('stores balances in canonical asset-id order', () {
        final snapshot = _accountSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-usd', amount: '100'),
            _incoming(assetId: 'asset-btc', amount: '0.5'),
            _incoming(assetId: 'asset-eur', amount: '50'),
          ],
        );

        expect(
          snapshot.assetBalances
              .map((balance) => balance.assetId.value)
              .toList(),
          ['asset-btc', 'asset-eur', 'asset-usd'],
        );
      });

      test(
        'equivalent snapshots compare equally regardless of input balance order',
        () {
          final first = _accountSnapshot(
            assetBalances: [
              _incoming(assetId: 'asset-usd', amount: '100'),
              _incoming(assetId: 'asset-btc', amount: '0.5'),
            ],
          );

          final equivalent = _accountSnapshot(
            assetBalances: [
              _incoming(assetId: 'asset-btc', amount: '0.5'),
              _incoming(assetId: 'asset-usd', amount: '100'),
            ],
          );

          expect(first, equivalent);
          expect(first.hashCode, equivalent.hashCode);
        },
      );
    });

    group('mapping', () {
      test('round-trips an account snapshot through mapping', () {
        final snapshot = _accountSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-btc', amount: '0.5'),
            _incoming(assetId: 'asset-usd', amount: '1200'),
          ],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '15000'),
        );

        final restored = BalanceSnapshotMapper.fromMap(snapshot.toMap());

        expect(restored, snapshot);
      });

      test('round-trips a custodian snapshot through mapping', () {
        final snapshot = _custodianSnapshot(
          assetBalances: [
            _incoming(assetId: 'asset-eur', amount: '100'),
            _outgoing(assetId: 'asset-usd', amount: '25'),
          ],
          valuationAmount: _incoming(assetId: 'asset-chf', amount: '70'),
        );

        final restored = BalanceSnapshotMapper.fromMap(snapshot.toMap());

        expect(restored, snapshot);
      });

      test('round-trips a jar snapshot through mapping', () {
        final snapshot = _jarSnapshot();

        final restored = BalanceSnapshotMapper.fromMap(snapshot.toMap());

        expect(restored, snapshot);
      });
    });
  });
}

BalanceSnapshot _accountSnapshot({
  CalendarDate? snapshotDate,
  DateTime? capturedAt,
  List<AssetAmount>? assetBalances,
  AssetAmount? valuationAmount,
}) {
  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.account(AccountId.fromString('account-1')),
    snapshotDate: snapshotDate ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 19, 20),
    assetBalances:
        assetBalances ?? [_incoming(assetId: 'asset-eur', amount: '125.50')],
    valuationAmount:
        valuationAmount ?? _incoming(assetId: 'asset-chf', amount: '119.25'),
  );
}

BalanceSnapshot _custodianSnapshot({
  CalendarDate? snapshotDate,
  DateTime? capturedAt,
  List<AssetAmount>? assetBalances,
  AssetAmount? valuationAmount,
}) {
  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.custodian(
      CustodianId.fromString('custodian-1'),
    ),
    snapshotDate: snapshotDate ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 19, 20),
    assetBalances:
        assetBalances ?? [_incoming(assetId: 'asset-eur', amount: '100')],
    valuationAmount:
        valuationAmount ?? _incoming(assetId: 'asset-chf', amount: '95'),
  );
}

BalanceSnapshot _jarSnapshot({
  CalendarDate? snapshotDate,
  DateTime? capturedAt,
  List<AssetAmount>? assetBalances,
  AssetAmount? valuationAmount,
}) {
  return BalanceSnapshot(
    subject: BalanceSnapshotSubject.jar(JarId.fromString('jar-1')),
    snapshotDate: snapshotDate ?? CalendarDate(2026, 9, 19),
    capturedAt: capturedAt ?? DateTime.utc(2026, 9, 19, 20),
    assetBalances:
        assetBalances ?? [_incoming(assetId: 'asset-chf', amount: '250')],
    valuationAmount:
        valuationAmount ?? _incoming(assetId: 'asset-chf', amount: '250'),
  );
}

AssetAmount _incoming({required String assetId, required String amount}) {
  return AssetAmount.incoming(
    assetId: AssetId.fromString(assetId),
    amount: Decimal.parse(amount),
  );
}

AssetAmount _outgoing({required String assetId, required String amount}) {
  return AssetAmount.outgoing(
    assetId: AssetId.fromString(assetId),
    amount: Decimal.parse(amount),
  );
}
