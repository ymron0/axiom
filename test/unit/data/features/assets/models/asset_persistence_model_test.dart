@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/data/models/asset_persistence_model.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('AssetPersistenceModel', () {
    group('type persistence', () {
      test('persists Currency discriminator and payment state', () {
        // Given
        final asset = currencyFixture();

        // When
        final record = AssetPersistenceModel.fromEntity(asset).toRecord();

        // Then
        expect(record[AssetPersistenceModel.typeField], 'currency');
        expect(
          record[AssetPersistenceModel.paymentEnabledField],
          isTrue,
        );
      });

      test('persists CryptoAsset discriminator and payment state', () {
        // Given
        final asset = cryptoAssetFixture(paymentEnabled: true);

        // When
        final record = AssetPersistenceModel.fromEntity(asset).toRecord();

        // Then
        expect(record[AssetPersistenceModel.typeField], 'crypto');
        expect(
          record[AssetPersistenceModel.paymentEnabledField],
          isTrue,
        );
      });

      test('persists StockAsset discriminator and payment state', () {
        // Given
        final asset = stockAssetFixture();

        // When
        final record = AssetPersistenceModel.fromEntity(asset).toRecord();

        // Then
        expect(record[AssetPersistenceModel.typeField], 'stock');
        expect(
          record[AssetPersistenceModel.paymentEnabledField],
          isFalse,
        );
      });

      test('persists CommodityAsset discriminator and payment state', () {
        // Given
        final asset = commodityAssetFixture();

        // When
        final record = AssetPersistenceModel.fromEntity(asset).toRecord();

        // Then
        expect(record[AssetPersistenceModel.typeField], 'commodity');
        expect(
          record[AssetPersistenceModel.paymentEnabledField],
          isFalse,
        );
      });
    });

    group('round trip', () {
      test('round-trips a Currency', () {
        // Given
        final original = currencyFixture(id: 'asset-eur');

        // When
        final rebuilt = _roundTrip(original);

        // Then
        expect(rebuilt, original);
        expect(rebuilt, isA<Currency>());
        expect(rebuilt.paymentEnabled, isTrue);
      });

      test('round-trips a payment-disabled CryptoAsset', () {
        // Given
        final original = cryptoAssetFixture(
          id: 'asset-btc-disabled',
          paymentEnabled: false,
        );

        // When
        final rebuilt = _roundTrip(original);

        // Then
        expect(rebuilt, original);
        expect(rebuilt, isA<CryptoAsset>());
        expect(rebuilt.paymentEnabled, isFalse);
      });

      test('round-trips a payment-enabled CryptoAsset', () {
        // Given
        final original = cryptoAssetFixture(
          id: 'asset-btc-enabled',
          paymentEnabled: true,
        );

        // When
        final rebuilt = _roundTrip(original);

        // Then
        expect(rebuilt, original);
        expect(rebuilt, isA<CryptoAsset>());
        expect(rebuilt.paymentEnabled, isTrue);
      });

      test('round-trips a StockAsset', () {
        // Given
        final original = stockAssetFixture(id: 'asset-nvda');

        // When
        final rebuilt = _roundTrip(original);

        // Then
        expect(rebuilt, original);
        expect(rebuilt, isA<StockAsset>());
        expect(rebuilt.paymentEnabled, isFalse);
      });

      test('round-trips a CommodityAsset', () {
        // Given
        final original = commodityAssetFixture(id: 'asset-xau');

        // When
        final rebuilt = _roundTrip(original);

        // Then
        expect(rebuilt, original);
        expect(rebuilt, isA<CommodityAsset>());
        expect(rebuilt.paymentEnabled, isFalse);
      });

      test('round-trips complete logo data', () {
        // Given
        final original = Currency(
          id: AssetId.fromString('asset-eur'),
          entityVersion: 1,
          createdAt: DateTime.utc(2026, 1, 1),
          modifiedAt: DateTime.utc(2026, 1, 1),
          name: 'Euro',
          code: AssetCode('EUR'),
          decimalPlaces: 2,
          logo: EntityLogo(
            source: EntityLogoSource.remote,
            value: 'https://logo.test/euro',
          ),
        );

        // When
        final model = AssetPersistenceModel.fromEntity(original);
        final rebuilt = AssetPersistenceModel.fromRecord(
          recordKey: original.id.value,
          record: model.toRecord(),
        );

        // Then
        expect(rebuilt.toRecord()['logo'], <String, Object?>{
          'source': 'remote',
          'value': 'https://logo.test/euro',
        });
        expect(rebuilt.toEntity(), original);
      });
    });

    group('backward compatibility', () {
      test(
        'restores legacy Currency record without paymentEnabled as enabled',
        () {
          // Given
          final original = currencyFixture(id: 'legacy-eur');
          final record = Map<String, Object?>.from(
            AssetPersistenceModel.fromEntity(original).toRecord(),
          )..remove(AssetPersistenceModel.paymentEnabledField);

          // When
          final model = AssetPersistenceModel.fromRecord(
            recordKey: original.id.value,
            record: record,
          );
          final rebuilt = model.toEntity();

          // Then
          expect(rebuilt, isA<Currency>());
          expect(rebuilt.paymentEnabled, isTrue);
        },
      );

      test('rejects CryptoAsset record without paymentEnabled', () {
        // Given
        final original = cryptoAssetFixture();
        final record = Map<String, Object?>.from(
          AssetPersistenceModel.fromEntity(original).toRecord(),
        )..remove(AssetPersistenceModel.paymentEnabledField);

        // When / Then
        expect(
          () => AssetPersistenceModel.fromRecord(
            recordKey: original.id.value,
            record: record,
          ),
          throwsA(
            isA<PersistenceRecordException>().having(
              (error) => error.field,
              'field',
              AssetPersistenceModel.paymentEnabledField,
            ),
          ),
        );
      });
    });

    group('payment invariant validation', () {
      test('rejects persisted Currency with paymentEnabled false', () {
        // Given
        final original = currencyFixture();
        final record = <String, Object?>{
          ...AssetPersistenceModel.fromEntity(original).toRecord(),
          AssetPersistenceModel.paymentEnabledField: false,
        };

        final model = AssetPersistenceModel.fromRecord(
          recordKey: original.id.value,
          record: record,
        );

        // When / Then
        expect(
          model.toEntity,
          throwsA(
            isA<PersistenceRecordException>().having(
              (error) => error.field,
              'field',
              AssetPersistenceModel.paymentEnabledField,
            ),
          ),
        );
      });

      test('rejects persisted StockAsset with paymentEnabled true', () {
        // Given
        final original = stockAssetFixture();
        final record = <String, Object?>{
          ...AssetPersistenceModel.fromEntity(original).toRecord(),
          AssetPersistenceModel.paymentEnabledField: true,
        };

        final model = AssetPersistenceModel.fromRecord(
          recordKey: original.id.value,
          record: record,
        );

        // When / Then
        expect(
          model.toEntity,
          throwsA(
            isA<PersistenceRecordException>().having(
              (error) => error.field,
              'field',
              AssetPersistenceModel.paymentEnabledField,
            ),
          ),
        );
      });

      test('rejects persisted CommodityAsset with paymentEnabled true', () {
        // Given
        final original = commodityAssetFixture();
        final record = <String, Object?>{
          ...AssetPersistenceModel.fromEntity(original).toRecord(),
          AssetPersistenceModel.paymentEnabledField: true,
        };

        final model = AssetPersistenceModel.fromRecord(
          recordKey: original.id.value,
          record: record,
        );

        // When / Then
        expect(
          model.toEntity,
          throwsA(
            isA<PersistenceRecordException>().having(
              (error) => error.field,
              'field',
              AssetPersistenceModel.paymentEnabledField,
            ),
          ),
        );
      });

      test('accepts both CryptoAsset payment states', () {
        // Given
        final disabled = cryptoAssetFixture(
          id: 'crypto-disabled',
          paymentEnabled: false,
        );
        final enabled = cryptoAssetFixture(
          id: 'crypto-enabled',
          paymentEnabled: true,
        );

        // When
        final rebuiltDisabled = _roundTrip(disabled);
        final rebuiltEnabled = _roundTrip(enabled);

        // Then
        expect(rebuiltDisabled.paymentEnabled, isFalse);
        expect(rebuiltEnabled.paymentEnabled, isTrue);
      });
    });

    group('corrupt persistence', () {
      test('rejects malformed timestamp and logo source records', () {
        // Given
        final record = AssetPersistenceModel.fromEntity(
          currencyFixture(),
        ).toRecord();

        // When / Then
        expect(
          () => AssetPersistenceModel.fromRecord(
            recordKey: 'asset-1',
            record: <String, Object?>{
              ...record,
              'createdAt': '2026-01-01',
            },
          ),
          throwsA(isA<PersistenceRecordException>()),
        );

        expect(
          () => AssetPersistenceModel.fromRecord(
            recordKey: 'asset-1',
            record: <String, Object?>{
              ...record,
              'logo': <String, Object?>{
                'source': 'unknown',
                'value': 'logo',
              },
            },
          ),
          throwsA(isA<PersistenceRecordException>()),
        );
      });

      test('rejects non-boolean paymentEnabled value', () {
        // Given
        final record = AssetPersistenceModel.fromEntity(
          cryptoAssetFixture(),
        ).toRecord();

        // When / Then
        expect(
          () => AssetPersistenceModel.fromRecord(
            recordKey: 'asset-btc',
            record: <String, Object?>{
              ...record,
              AssetPersistenceModel.paymentEnabledField: 'true',
            },
          ),
          throwsA(isA<PersistenceRecordException>()),
        );
      });

      test('rejects unsupported asset types during reconstruction', () {
        // Given
        final record = AssetPersistenceModel.fromEntity(
          currencyFixture(),
        ).toRecord();

        final model = AssetPersistenceModel.fromRecord(
          recordKey: 'asset-1',
          record: <String, Object?>{
            ...record,
            AssetPersistenceModel.typeField: 'fund',
            AssetPersistenceModel.paymentEnabledField: false,
          },
        );

        // When / Then
        expect(
          model.toEntity,
          throwsA(isA<PersistenceRecordException>()),
        );
      });

      test(
        'converts invalid reconstructed asset state to persistence exception',
        () {
          // Given
          final record = AssetPersistenceModel.fromEntity(
            currencyFixture(),
          ).toRecord();

          final model = AssetPersistenceModel.fromRecord(
            recordKey: '',
            record: record,
          );

          // When / Then
          expect(
            model.toEntity,
            throwsA(isA<PersistenceRecordException>()),
          );
        },
      );
    });
  });
}

Asset _roundTrip(Asset original) {
  final model = AssetPersistenceModel.fromEntity(original);

  final rebuilt = AssetPersistenceModel.fromRecord(
    recordKey: original.id.value,
    record: model.toRecord(),
  );

  return rebuilt.toEntity();
}