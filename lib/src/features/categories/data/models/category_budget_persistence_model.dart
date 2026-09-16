import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';

/// Persistence representation of a [CategoryBudget].
///
/// Budget rules are embedded inside their owning category record rather than
/// stored in a separate Sembast store.
///
/// ## Amounts
///
/// [limit] uses [AssetAmountPersistenceModel], keeping asset identifiers,
/// directions, and exact decimal amounts independent from generated domain
/// serialization.
///
/// ## Dates
///
/// Effective dates are calendar dates rather than instants.
///
/// They are therefore serialized using the stable `YYYY-MM-DD` representation
/// produced by [CalendarDate.toString], without introducing a timezone or time
/// component.
///
/// [effectiveFrom] is inclusive.
///
/// [effectiveUntil] is exclusive and may be `null` for an open-ended rule.
///
/// ## Failure behavior
///
/// Persisted values are treated as untrusted input.
///
/// Structural errors, unsupported enum values, malformed calendar dates, and
/// invalid nested amounts result in [PersistenceRecordException].
final class CategoryBudgetPersistenceModel {
  static const String _limitField = 'limit';
  static const String _periodField = 'period';
  static const String _effectiveFromField = 'effectiveFrom';
  static const String _effectiveUntilField = 'effectiveUntil';

  /// Persisted budget limit.
  final AssetAmountPersistenceModel limit;

  /// Recurring budget period.
  final BudgetPeriod period;

  /// Inclusive first effective calendar date.
  final CalendarDate effectiveFrom;

  /// Exclusive first ineffective calendar date.
  final CalendarDate? effectiveUntil;

  /// Creates a persistence representation of a category budget.
  const CategoryBudgetPersistenceModel({
    required this.limit,
    required this.period,
    required this.effectiveFrom,
    required this.effectiveUntil,
  });

  /// Creates a persistence model from the valid domain [budget].
  factory CategoryBudgetPersistenceModel.fromEntity(CategoryBudget budget) {
    return CategoryBudgetPersistenceModel(
      limit: AssetAmountPersistenceModel.fromEntity(budget.limit),
      period: budget.period,
      effectiveFrom: budget.effectiveFrom,
      effectiveUntil: budget.effectiveUntil,
    );
  }

  /// Reconstructs a budget persistence model from [record].
  ///
  /// [path] identifies this budget inside the containing category record.
  ///
  /// Throws [PersistenceRecordException] when persisted structure or values
  /// are invalid.
  factory CategoryBudgetPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      return CategoryBudgetPersistenceModel(
        limit: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_limitField),
          path: '$path.$_limitField',
        ),
        period: readPersistenceEnum(
          reader: reader,
          field: _periodField,
          values: BudgetPeriod.values,
        ),
        effectiveFrom: _readCalendarDate(
          reader.requiredString(_effectiveFromField),
          field: _effectiveFromField,
        ),
        effectiveUntil: _readOptionalCalendarDate(reader, _effectiveUntilField),
      );
    });
  }

  /// Converts this model into its primitive persistence representation.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _limitField: limit.toRecord(),
      _periodField: period.name,
      _effectiveFromField: effectiveFrom.toString(),
      _effectiveUntilField: effectiveUntil?.toString(),
    };
  }

  /// Reconstructs the domain [CategoryBudget] represented by this model.
  ///
  /// Domain invariants are deliberately revalidated by the domain constructor.
  CategoryBudget toEntity() {
    return CategoryBudget(
      limit: limit.toEntity(),
      period: period,
      effectiveFrom: effectiveFrom,
      effectiveUntil: effectiveUntil,
    );
  }

  /// Reads an optional calendar-date field.
  static CalendarDate? _readOptionalCalendarDate(
    PersistenceRecordReader reader,
    String field,
  ) {
    final value = reader.optionalString(field);

    if (value == null) {
      return null;
    }

    return _readCalendarDate(value, field: field);
  }

  /// Parses the stable `YYYY-MM-DD` calendar-date representation.
  ///
  /// A timestamp such as `2026-01-01T00:00:00Z` is intentionally rejected:
  /// effective dates are date-only domain values.
  static CalendarDate _readCalendarDate(String value, {required String field}) {
    final match = RegExp(r'^(-?\d+)-(\d{2})-(\d{2})$').firstMatch(value);

    if (match == null) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a calendar date in YYYY-MM-DD format.',
      );
    }

    try {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);

      return CalendarDate(year, month, day);
    } on FormatException {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a valid calendar date.',
      );
    } on ArgumentError {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a valid calendar date.',
      );
    }
  }
}
