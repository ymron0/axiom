/// Width classes used by responsive presentation layouts.
enum WindowSizeClass {
  /// Widths below 600dp.
  compact(minWidth: 0),

  /// Widths from 600dp to below 840dp.
  medium(minWidth: 600),

  /// Widths from 840dp upward.
  expanded(minWidth: 840);

  /// Minimum width at which this size class applies.
  final double minWidth;

  const WindowSizeClass({required this.minWidth});

  /// Resolves the size class for [width].
  static WindowSizeClass fromWidth(double width) {
    if (width >= expanded.minWidth) {
      return expanded;
    }

    if (width >= medium.minWidth) {
      return medium;
    }

    return compact;
  }
}
