import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Owns global Material 3 theme construction.
///
/// Feature presentation code consumes the resulting [ThemeData] through
/// [Theme.of] and must not independently construct competing application-wide
/// themes.
///
/// Primitive visual constants are owned by the design-token classes under
/// `core/presentation/tokens`.
///
/// ## Invariants
///
/// The produced theme always uses Material 3.
///
/// The theme is generated from exactly one application seed color.
///
/// Global interactive controls retain accessible Material target dimensions.
///
/// ## Semantics
///
/// Material's [ColorScheme] remains the primary source of semantic colors.
///
/// Design tokens provide primitive dimensions and motion values. Component
/// themes compose those primitives into application-wide Material styling.
///
/// Feature-specific concepts such as transaction direction, budget state, or
/// entity colors do not belong here.
///
/// ## Contract
///
/// Theme construction is deterministic and cannot produce an expected
/// recoverable failure.
///
/// Invalid theme or token constants are programmer errors rather than
/// application failures and must not be converted into `Result` values.
abstract final class AppTheme {
  /// Global light Material 3 theme.
  static final ThemeData light = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColorTokens.seed,
      brightness: Brightness.light,
    );

    final baseTheme = ThemeData.from(
      colorScheme: colorScheme,
      useMaterial3: true,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: _appBarTheme(colorScheme),
      navigationBarTheme: _navigationBarTheme(colorScheme),
      cardTheme: _cardTheme(colorScheme),
      bottomSheetTheme: _bottomSheetTheme(colorScheme),
      dialogTheme: _dialogTheme(colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      iconButtonTheme: _iconButtonTheme(),
      floatingActionButtonTheme: _floatingActionButtonTheme(colorScheme),
      dividerTheme: _dividerTheme(colorScheme),
      listTileTheme: _listTileTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(),
    );
  }

  static AppBarThemeData _appBarTheme(ColorScheme colorScheme) {
    return AppBarThemeData(
      centerTitle: false,
      elevation: AppElevation.level0,
      scrolledUnderElevation: AppElevation.level0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.medium,
    );
  }

  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme colorScheme,
  ) {
    return NavigationBarThemeData(
      height: AppSize.navigationBarHeight,
      elevation: AppElevation.level0,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    );
  }

  static CardThemeData _cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: AppElevation.level0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(
    ColorScheme colorScheme,
  ) {
    return BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      modalBackgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level0,
      modalElevation: AppElevation.level1,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xLarge),
        ),
      ),
    );
  }

  static DialogThemeData _dialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(
      elevation: AppElevation.level1,
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
      ),
    );
  }

  static InputDecorationThemeData _inputDecorationTheme(
    ColorScheme colorScheme,
  ) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      borderSide: BorderSide(
        color: colorScheme.outline,
      ),
    );

    return InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      border: border,
      enabledBorder: border.copyWith(
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(
          color: colorScheme.error,
        ),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 2,
        ),
      ),
    );
  }

  static IconButtonThemeData _iconButtonTheme() {
    return IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(AppSize.interactive),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData _floatingActionButtonTheme(
    ColorScheme colorScheme,
  ) {
    return FloatingActionButtonThemeData(
      elevation: AppElevation.level1,
      focusElevation: AppElevation.level2,
      hoverElevation: AppElevation.level2,
      highlightElevation: AppElevation.level2,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    );
  }

  static DividerThemeData _dividerTheme(ColorScheme colorScheme) {
    return DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    );
  }

  static ListTileThemeData _listTileTheme() {
    return ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
      ),
      minVerticalPadding: AppSpacing.xSmall,
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(
            64,
            AppSize.interactive,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    ColorScheme colorScheme,
  ) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(
            64,
            AppSize.interactive,
          ),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: colorScheme.outline,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(
            AppSize.interactive,
            AppSize.interactive,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }
}