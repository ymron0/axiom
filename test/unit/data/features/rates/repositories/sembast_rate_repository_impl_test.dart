@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_already_exists_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_persistence_failure.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  late Database database;
  late RateRepository repository;

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastRateRepositoryImpl(database: database);
  });

  group('SembastRateRepositoryImpl', () {
    group('create', () {
      test('persists and reads a rate', () async {
        // Given
        final rate = exchangeRateFixture(id: 'create-rate');

        // When
        final result = await repository.create(rate);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(rate.id)).valueOrNull;
        expect(stored?.id, rate.id);
        expect(stored?.baseAssetId, rate.baseAssetId);
        expect(stored?.quoteAssetId, rate.quoteAssetId);
        expect(stored?.rate, rate.rate);
        expect(stored?.effectiveAt, rate.effectiveAt);
      });

      test('rejects a duplicate ID without mutation', () async {
        // Given
        final original = exchangeRateFixture(
          id: 'duplicate-rate',
          rate: '1.10',
        );
        final duplicate = exchangeRateFixture(
          id: original.id.value,
          rate: '9.99',
        );

        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<RateAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull?.rate,
          original.rate,
        );
      });

      test('returns RateNotFoundFailure for missing ID', () async {
        // When
        final result = await repository.getById(
          RateId.fromString('missing-rate'),
        );

        // Then
        expect(result.failureOrNull, isA<RateNotFoundFailure>());
      });
    });

    group('createAll', () {
      test('persists the whole batch', () async {
        // Given
        final first = exchangeRateFixture(id: 'batch-first');
        final second = exchangeRateFixture(id: 'batch-second');

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.isSuccess, isTrue);

        expect((await repository.getById(first.id)).valueOrNull?.id, first.id);
        expect(
          (await repository.getById(second.id)).valueOrNull?.id,
          second.id,
        );
      });

      test('is atomic when one ID already exists', () async {
        // Given
        final existing = exchangeRateFixture(id: 'batch-existing');
        final fresh = exchangeRateFixture(id: 'batch-fresh');

        await repository.create(existing);

        // When
        final result = await repository.createAll([fresh, existing]);

        // Then
        expect(result.failureOrNull, isA<RateAlreadyExistsFailure>());

        expect(
          (await repository.getById(fresh.id)).failureOrNull,
          isA<RateNotFoundFailure>(),
        );
      });

      test('is atomic when request contains duplicate IDs', () async {
        // Given
        final first = exchangeRateFixture(id: 'batch-duplicate', rate: '1.10');
        final duplicate = exchangeRateFixture(id: first.id.value, rate: '2.00');

        // When
        final result = await repository.createAll([first, duplicate]);

        // Then
        expect(result.failureOrNull, isA<RateAlreadyExistsFailure>());

        expect(
          (await repository.getById(first.id)).failureOrNull,
          isA<RateNotFoundFailure>(),
        );
      });
    });

    group('getByIds', () {
      test('separates found and missing IDs with immutable results', () async {
        // Given
        final first = exchangeRateFixture(id: 'lookup-first');
        final second = exchangeRateFixture(id: 'lookup-second');
        final missing = RateId.fromString('lookup-missing');

        await repository.createAll([first, second]);

        // When
        final result = await repository.getByIds([
          missing,
          second.id,
          first.id,
          missing,
        ]);

        // Then
        final lookup = result.valueOrNull!;

        expect(lookup.found.map((rate) => rate.id), [second.id, first.id]);
        expect(lookup.missing, [missing]);

        expect(() => lookup.found.clear(), throwsUnsupportedError);
        expect(() => lookup.missing.clear(), throwsUnsupportedError);
      });
    });

    group('pair queries', () {
      test('returns exact ordered pair sorted by effectiveAt', () async {
        // Given
        final older = exchangeRateFixture(
          id: 'pair-older',
          baseAssetId: 'TEST-BASE',
          quoteAssetId: 'TEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 9),
        );

        final newer = exchangeRateFixture(
          id: 'pair-newer',
          baseAssetId: 'TEST-BASE',
          quoteAssetId: 'TEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 11),
        );

        final inverse = exchangeRateFixture(
          id: 'pair-inverse',
          baseAssetId: 'TEST-QUOTE',
          quoteAssetId: 'TEST-BASE',
          effectiveAt: DateTime.utc(2026, 9, 10),
        );

        await repository.createAll([newer, inverse, older]);

        // When
        final result = await repository.getByPair(
          baseAssetId: AssetId.fromString('TEST-BASE'),
          quoteAssetId: AssetId.fromString('TEST-QUOTE'),
        );

        // Then
        final rates = result.valueOrNull!;

        expect(rates.map((rate) => rate.id), [older.id, newer.id]);
        expect(() => rates.clear(), throwsUnsupportedError);
      });

      test('returns immutable empty result for missing pair', () async {
        // When
        final result = await repository.getByPair(
          baseAssetId: AssetId.fromString('UNKNOWN-BASE'),
          quoteAssetId: AssetId.fromString('UNKNOWN-QUOTE'),
        );

        // Then
        final rates = result.valueOrNull!;

        expect(rates, isEmpty);
        expect(() => rates.clear(), throwsUnsupportedError);
      });

      test('latest means greatest effectiveAt', () async {
        // Given
        final financiallyOlder = exchangeRateFixture(
          id: 'latest-older',
          baseAssetId: 'LATEST-BASE',
          quoteAssetId: 'LATEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 9),
          createdAt: DateTime.utc(2026, 9, 20),
          modifiedAt: DateTime.utc(2026, 9, 20),
        );

        final financiallyNewer = exchangeRateFixture(
          id: 'latest-newer',
          baseAssetId: 'LATEST-BASE',
          quoteAssetId: 'LATEST-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 11),
          createdAt: DateTime.utc(2026, 9, 1),
          modifiedAt: DateTime.utc(2026, 9, 1),
        );

        await repository.createAll([financiallyNewer, financiallyOlder]);

        // When
        final result = await repository.getLatestByPair(
          baseAssetId: AssetId.fromString('LATEST-BASE'),
          quoteAssetId: AssetId.fromString('LATEST-QUOTE'),
        );

        // Then
        expect(result.valueOrNull?.id, financiallyNewer.id);
      });

      test('returns RateNotFoundFailure when latest pair is missing', () async {
        // When
        final result = await repository.getLatestByPair(
          baseAssetId: AssetId.fromString('MISSING-BASE'),
          quoteAssetId: AssetId.fromString('MISSING-QUOTE'),
        );

        // Then
        expect(result.failureOrNull, isA<RateNotFoundFailure>());
      });
    });

    group('as-of query', () {
      test(
        'returns greatest effectiveAt at or before requested instant',
        () async {
          // Given
          final older = exchangeRateFixture(
            id: 'as-of-older',
            baseAssetId: 'ASOF-BASE',
            quoteAssetId: 'ASOF-QUOTE',
            effectiveAt: DateTime.utc(2026, 9, 9),
          );

          final exact = exchangeRateFixture(
            id: 'as-of-exact',
            baseAssetId: 'ASOF-BASE',
            quoteAssetId: 'ASOF-QUOTE',
            effectiveAt: DateTime.utc(2026, 9, 10),
          );

          final future = exchangeRateFixture(
            id: 'as-of-future',
            baseAssetId: 'ASOF-BASE',
            quoteAssetId: 'ASOF-QUOTE',
            effectiveAt: DateTime.utc(2026, 9, 11),
          );

          await repository.createAll([future, older, exact]);

          // When
          final result = await repository.getAtOrBefore(
            baseAssetId: AssetId.fromString('ASOF-BASE'),
            quoteAssetId: AssetId.fromString('ASOF-QUOTE'),
            effectiveAt: DateTime.utc(2026, 9, 10),
          );

          // Then
          expect(result.valueOrNull?.id, exact.id);
        },
      );

      test('compares equivalent timezone representations by instant', () async {
        // Given
        final rate = exchangeRateFixture(
          id: 'timezone-rate',
          baseAssetId: 'TIME-BASE',
          quoteAssetId: 'TIME-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 10, 12),
        );

        await repository.create(rate);

        // When
        final result = await repository.getAtOrBefore(
          baseAssetId: AssetId.fromString('TIME-BASE'),
          quoteAssetId: AssetId.fromString('TIME-QUOTE'),
          effectiveAt: DateTime.parse('2026-09-10T14:00:00+02:00'),
        );

        // Then
        expect(result.valueOrNull?.id, rate.id);
      });

      test('does not return a future observation', () async {
        // Given
        final rate = exchangeRateFixture(
          id: 'future-only',
          baseAssetId: 'FUTURE-BASE',
          quoteAssetId: 'FUTURE-QUOTE',
          effectiveAt: DateTime.utc(2026, 9, 11),
        );

        await repository.create(rate);

        // When
        final result = await repository.getAtOrBefore(
          baseAssetId: AssetId.fromString('FUTURE-BASE'),
          quoteAssetId: AssetId.fromString('FUTURE-QUOTE'),
          effectiveAt: DateTime.utc(2026, 9, 10),
        );

        // Then
        expect(result.failureOrNull, isA<RateNotFoundFailure>());
      });
    });

    test('translates malformed persisted rate to typed failure', () async {
      // Given
      const id = 'corrupt-rate';

      await SembastStores.rates.record(id).put(database, <String, Object?>{});

      // When
      final result = await repository.getById(RateId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<RatePersistenceFailure>());
    });
  });
}
