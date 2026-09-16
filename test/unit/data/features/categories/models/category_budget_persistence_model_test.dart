@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/categories/data/models/category_budget_persistence_model.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryBudgetPersistenceModel', () {
    final model = CategoryBudgetPersistenceModel(
      limit: AssetAmountPersistenceModel(
        assetId: 'asset-1',
        amount: Decimal.fromInt(100),
        direction: AssetAmountDirection.outgoing,
      ),
      period: BudgetPeriod.monthly,
      effectiveFrom: CalendarDate(2026, 1, 1),
      effectiveUntil: CalendarDate(2026, 2, 1),
    );

    test('round-trips a dated budget', () {
      final record = model.toRecord();
      final rebuilt = CategoryBudgetPersistenceModel.fromRecord(
        record,
        path: 'budgets[0]',
      );

      expect(rebuilt.toEntity(), model.toEntity());
    });

    test('rejects malformed dates, enum values, and invalid date ranges', () {
      final record = model.toRecord();
      expect(
        () => CategoryBudgetPersistenceModel.fromRecord(
          <String, Object?>{...record, 'effectiveFrom': '2026-1-01'},
          path: 'budgets[0]',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => CategoryBudgetPersistenceModel.fromRecord(
          <String, Object?>{...record, 'period': 'never'},
          path: 'budgets[0]',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final invalid = CategoryBudgetPersistenceModel.fromRecord(
        <String, Object?>{...record, 'effectiveUntil': '2025-12-31'},
        path: 'budgets[0]',
      );
      expect(invalid.toEntity, throwsArgumentError);
    });

    test('rejects calendar dates with invalid values', () {
      final record = model.toRecord();

      expect(
        () => CategoryBudgetPersistenceModel.fromRecord(
          <String, Object?>{...record, 'effectiveFrom': '2026-13-01'},
          path: 'budgets[0]',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => CategoryBudgetPersistenceModel.fromRecord(
          <String, Object?>{
            ...record,
            'effectiveFrom': '${List.filled(1000, '9').join()}-01-01',
          },
          path: 'budgets[0]',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });
  });
}
