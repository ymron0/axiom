import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Primary destinations exposed by the application's persistent navigation.
///
/// The declaration order must match the routes configured by `AppShellPage`.
///
/// ## Semantics
///
/// Each destination owns the user-facing label and icon used by both compact
/// and wider navigation layouts.
///
/// ## Contract
///
/// A destination index is stable for the lifetime of the running application.
/// Persistent user customization, when introduced, should map destinations by
/// identity rather than by storing these indices directly.
enum AppNavigationDestination {
  home(label: 'Home', icon: Symbols.home_rounded),
  activity(label: 'Activity', icon: Symbols.receipt_long_rounded),
  accounts(label: 'Accounts', icon: Symbols.account_balance_wallet_rounded),
  categories(label: 'Categories', icon: Symbols.category_rounded),
  more(label: 'More', icon: Symbols.more_horiz_rounded);

  /// User-facing destination label.
  final String label;

  /// Rounded Material Symbol used by the destination.
  final IconData icon;

  const AppNavigationDestination({required this.label, required this.icon});

  /// Creates the compact-navigation representation.
  NavigationDestination toNavigationDestination() {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(icon, fill: 1),
      label: label,
    );
  }

  /// Creates the navigation-rail representation.
  NavigationRailDestination toNavigationRailDestination() {
    return NavigationRailDestination(
      icon: Icon(icon),
      selectedIcon: Icon(icon, fill: 1),
      label: Text(label),
    );
  }
}
