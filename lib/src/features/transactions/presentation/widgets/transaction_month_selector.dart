import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontally scrollable calendar-month selector.
///
/// This deliberately uses plain text cells and a selected underline rather
/// than chips or elevated cards.
final class TransactionMonthSelector extends StatefulWidget {
  final DateTime selectedMonth;
  final int currentYear;
  final ValueChanged<DateTime> onSelected;

  /// Creates the month selector.
  const TransactionMonthSelector({
    required this.selectedMonth,
    required this.currentYear,
    required this.onSelected,
    super.key,
  });

  @override
  State<TransactionMonthSelector> createState() =>
      _TransactionMonthSelectorState();
}

final class _TransactionMonthSelectorState
    extends State<TransactionMonthSelector> {
  static const _itemWidth = 64.0;
  static const _selectedIndex = 12;

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ScrollController(
      initialScrollOffset: (_selectedIndex * _itemWidth) - (2.25 * _itemWidth),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.MMM(locale);

    return SizedBox(
      height: 58,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: 25,
        itemExtent: _itemWidth,
        itemBuilder: (context, index) {
          final offset = index - _selectedIndex;

          final month = DateTime(
            widget.selectedMonth.year,
            widget.selectedMonth.month + offset,
          );

          final selected =
              month.year == widget.selectedMonth.year &&
              month.month == widget.selectedMonth.month;

          final showYear = month.year != widget.currentYear;

          return Semantics(
            button: true,
            selected: selected,
            label: showYear
                ? '${formatter.format(month)} ${month.year}'
                : formatter.format(month),
            child: InkWell(
              onTap: () => widget.onSelected(month),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: selected ? 2 : 0,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxSmall,
                  vertical: AppSpacing.xSmall,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatter.format(month),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (showYear)
                      Text(
                        '${month.year}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
