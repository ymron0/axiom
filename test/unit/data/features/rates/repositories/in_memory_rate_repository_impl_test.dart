import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/rate_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/features/rates/data/repositories/in_memory_rate_repository_impl.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  group('InMemoryRateRepositoryImpl', () {
    test('creates and gets a rate by ID', () async {
      final repository = InMemoryRateRepositoryImpl();
      final rate = exchangeRateFixture(id: 'created-rate');

      final result = await repository.create(rate);

      expect(result.isSuccess, isTrue);
      expect(
        (await repository.getById(
          RateId.fromString(rate.id.value),
        )).valueOrNull,
        same(rate),
      );
    });

    test('rejects duplicate IDs without mutating the repository', () async {
      final repository = InMemoryRateRepositoryImpl();
      final rate = exchangeRateFixture(id: 'duplicate-rate');
      await repository.create(rate);

      final result = await repository.create(
        exchangeRateFixture(id: 'duplicate-rate', rate: '2.00'),
      );

      expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
      expect(
        (await repository.getById(
          RateId.fromString(rate.id.value),
        )).valueOrNull,
        same(rate),
      );
    });

    test('returns RateNotFoundFailure for a missing ID', () async {
      final repository = InMemoryRateRepositoryImpl();

      final result = await repository.getById(
        RateId.fromString('missing-rate'),
      );

      expect(result.failureOrNull, isA<RateNotFoundFailure>());
    });

    test('createAll is atomic when a requested ID already exists', () async {
      final repository = InMemoryRateRepositoryImpl();
      final existing = exchangeRateFixture(id: 'existing-batch-rate');
      await repository.create(existing);
      final newRate = exchangeRateFixture(id: 'new-batch-rate');

      final result = await repository.createAll([newRate, existing]);

      expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
      expect(
        (await repository.getById(
          RateId.fromString(newRate.id.value),
        )).failureOrNull,
        isA<RateNotFoundFailure>(),
      );
    });

    test(
      'createAll is atomic when IDs are duplicated in the request',
      () async {
        final repository = InMemoryRateRepositoryImpl();
        final first = exchangeRateFixture(id: 'duplicate-batch-rate');
        final duplicate = exchangeRateFixture(
          id: 'duplicate-batch-rate',
          rate: '2.00',
        );

        final result = await repository.createAll([first, duplicate]);

        expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
        expect(
          (await repository.getById(
            RateId.fromString(first.id.value),
          )).failureOrNull,
          isA<RateNotFoundFailure>(),
        );
      },
    );

    test('returns missing IDs separately from found rates', () async {
      final repository = InMemoryRateRepositoryImpl();
      final existing = exchangeRateFixture(id: 'existing-rate');
      await repository.create(existing);
      final missing = RateId.fromString('missing-rate');

      final lookup = (await repository.getByIds([
        missing,
        RateId.fromString(existing.id.value),
        missing,
      ])).valueOrNull!;

      expect(lookup.found, [same(existing)]);
      expect(lookup.missing, [missing]);
    });

    test('returns a successful empty list for an unknown pair', () async {
      final repository = InMemoryRateRepositoryImpl();

      final result = await repository.getByPair(
        baseAssetId: AssetId.fromString('UNKNOWN-BASE'),
        quoteAssetId: AssetId.fromString('UNKNOWN-QUOTE'),
      );

      expect(result.valueOrNull, isEmpty);
    });

    test(
      'matches only the requested ordered pair and sorts by effective time',
      () async {
        final repository = InMemoryRateRepositoryImpl();
        final older = exchangeRateFixture(
          id: 'older-rate',
          baseAssetId: 'TEST-BASE',
          quoteAssetId: 'TEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 9),
        );
        final newer = exchangeRateFixture(
          id: 'newer-rate',
          baseAssetId: 'TEST-BASE',
          quoteAssetId: 'TEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 11),
        );
        final inverse = exchangeRateFixture(
          id: 'inverse-rate',
          baseAssetId: 'TEST-QUOTE',
          quoteAssetId: 'TEST-BASE',
        );
        await repository.createAll([newer, inverse, older]);

        final result = await repository.getByPair(
          baseAssetId: AssetId.fromString('TEST-BASE'),
          quoteAssetId: AssetId.fromString('TEST-QUOTE'),
        );

        expect(result.valueOrNull, [same(older), same(newer)]);
      },
    );

    test('selects the latest rate at or before an instant', () async {
      final repository = InMemoryRateRepositoryImpl();
      final older = exchangeRateFixture(
        id: 'as-of-older',
        baseAssetId: 'ASOF-BASE',
        quoteAssetId: 'ASOF-QUOTE',
        effectiveAt: DateTime.utc(2026, 9, 9),
      );
      final newer = exchangeRateFixture(
        id: 'as-of-newer',
        baseAssetId: 'ASOF-BASE',
        quoteAssetId: 'ASOF-QUOTE',
        effectiveAt: DateTime.utc(2026, 9, 11),
      );
      await repository.createAll([older, newer]);

      final result = await repository.getAtOrBefore(
        baseAssetId: AssetId.fromString('ASOF-BASE'),
        quoteAssetId: AssetId.fromString('ASOF-QUOTE'),
        effectiveAt: DateTime.utc(2026, 9, 10),
      );

      expect(result.valueOrNull, same(older));
    });

    test(
      'selects latest by effective time rather than insertion or audit time',
      () async {
        final repository = InMemoryRateRepositoryImpl();
        final older = exchangeRateFixture(
          id: 'latest-older',
          baseAssetId: 'LATEST-BASE',
          quoteAssetId: 'LATEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 9),
          createdAt: DateTime.utc(2026, 9, 12),
          modifiedAt: DateTime.utc(2026, 9, 12),
        );
        final newer = exchangeRateFixture(
          id: 'latest-newer',
          baseAssetId: 'LATEST-BASE',
          quoteAssetId: 'LATEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 11),
          createdAt: DateTime.utc(2026, 9, 1),
          modifiedAt: DateTime.utc(2026, 9, 1),
        );
        await repository.createAll([newer, older]);

        final result = await repository.getLatestByPair(
          baseAssetId: AssetId.fromString('LATEST-BASE'),
          quoteAssetId: AssetId.fromString('LATEST-QUOTE'),
        );

        expect(result.valueOrNull, same(newer));
      },
    );

    test(
      'accepts equivalent timezone representations for as-of lookup',
      () async {
        final repository = InMemoryRateRepositoryImpl();
        final rate = exchangeRateFixture(
          id: 'timezone-rate',
          baseAssetId: 'TIME-BASE',
          quoteAssetId: 'TIME-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 10, 12),
        );
        await repository.create(rate);

        final result = await repository.getAtOrBefore(
          baseAssetId: AssetId.fromString('TIME-BASE'),
          quoteAssetId: AssetId.fromString('TIME-QUOTE'),
          effectiveAt: DateTime.parse('2026-09-10T14:00:00+02:00'),
        );

        expect(result.valueOrNull, same(rate));
      },
    );

    test(
      'returns RateNotFoundFailure when the pair has no latest rate',
      () async {
        final repository = InMemoryRateRepositoryImpl();

        final result = await repository.getLatestByPair(
          baseAssetId: AssetId.fromString('MISSING-LATEST-BASE'),
          quoteAssetId: AssetId.fromString('MISSING-LATEST-QUOTE'),
        );

        expect(result.failureOrNull, isA<RateNotFoundFailure>());
      },
    );

    test('does not expose a mutable pair list', () async {
      final repository = InMemoryRateRepositoryImpl();
      final rate = exchangeRateFixture(
        id: 'immutable-list-rate',
        baseAssetId: 'IMMUTABLE-BASE',
        quoteAssetId: 'IMMUTABLE-QUOTE',
      );
      await repository.create(rate);

      final rates = (await repository.getByPair(
        baseAssetId: AssetId.fromString('IMMUTABLE-BASE'),
        quoteAssetId: AssetId.fromString('IMMUTABLE-QUOTE'),
      )).valueOrNull!;

      expect(() => rates.clear(), throwsUnsupportedError);
      expect(
        (await repository.getById(
          RateId.fromString(rate.id.value),
        )).valueOrNull,
        same(rate),
      );
    });

    test(
      'fails when no rate exists at or before the requested instant',
      () async {
        final repository = InMemoryRateRepositoryImpl();

        final result = await repository.getAtOrBefore(
          baseAssetId: AssetId.fromString('MISSING-BASE'),
          quoteAssetId: AssetId.fromString('MISSING-QUOTE'),
          effectiveAt: DateTime.utc(2020),
        );

        expect(result.failureOrNull, isA<RateNotFoundFailure>());
      },
    );
  });
}
